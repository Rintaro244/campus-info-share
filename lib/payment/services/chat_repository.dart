/// 学内情報共有システム — C4 取引・決済処理部
/// チャット Repository（メッセージのリアルタイム購読 + 送信）
///
/// 既存の PastExamRepository（lib/past/past_exam_repository.dart）の snapshots()
/// パターンを踏襲。チャットは古い→新しいの昇順で購読する。
/// テストではこのクラスを implements した Fake を差し替える。
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:student_information_1/payment/models/chat_message.dart';

/// メッセージの購読・送信を担う。
class ChatRepository {
  /// chats コレクション名（firestore.rules / constants.ts と一致）。
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';

  /// 本文の最大長（firestore.rules と一致させること）。
  static const int maxTextLength = 1000;

  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String roomId) {
    return _firestore
        .collection(chatsCollection)
        .doc(roomId)
        .collection(messagesCollection);
  }

  /// ルームのメッセージを作成時刻の昇順でリアルタイム購読する。
  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return _messagesRef(roomId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
        );
  }

  /// メッセージを送信する。空白のみ・上限超は送らない（Rules と同じガード）。
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxTextLength) return;
    await _messagesRef(roomId).add(
      ChatMessage.toCreateMap(senderId: senderId, text: trimmed),
    );
  }
}
