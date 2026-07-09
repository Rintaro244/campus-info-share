/// 学内情報共有システム — C4 取引・決済処理部
/// チャットメッセージモデル（chats/{roomId}/messages/{messageId}）
///
/// フィールドの確定値は functions/src/constants.ts / firestore.rules と一致させること。
/// 送信は Rules で senderId == 自分・本文 1〜1000 文字が要求される。
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// 1 件のチャットメッセージ。
class ChatMessage {
  /// メッセージのドキュメント ID。
  final String id;

  /// 送信者 uid（Rules で request.auth.uid と一致が必須）。
  final String senderId;

  /// 本文。
  final String text;

  /// 送信時刻。serverTimestamp 反映前は null になり得る（楽観表示の直後など）。
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  /// Firestore ドキュメントから読み取る。
  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  /// 送信時に messages へ書き込むマップ。createdAt はサーバ時刻を使う。
  static Map<String, dynamic> toCreateMap({
    required String senderId,
    required String text,
  }) {
    return <String, dynamic>{
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
