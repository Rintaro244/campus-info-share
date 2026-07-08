/// 学内情報共有システム — C4 取引・決済処理部
/// チャットルームモデル（chats/{roomId}。roomId = transactionId）
///
/// ルーム本体はサーバ(Admin SDK トリガー)が生成する（クライアント作成は Rules で禁止）。
/// 当事者判定は buyerId / sellerId で行う。フィールドは functions/src/constants.ts の
/// CHAT_FIELDS と一致させること。
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// 取引成立時に生成される購入者⇄出品者のチャットルーム。
class ChatRoom {
  /// ルーム ID（= transactionId。有償: `pi_xxx` / 無料: `free_<listingId>`）。
  final String roomId;
  final String buyerId;
  final String sellerId;
  final String listingId;
  final String transactionId;
  final DateTime? createdAt;

  const ChatRoom({
    required this.roomId,
    required this.buyerId,
    required this.sellerId,
    required this.listingId,
    required this.transactionId,
    this.createdAt,
  });

  /// Firestore ドキュメントから読み取る（取引履歴入口タスク等での再利用を想定）。
  factory ChatRoom.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    return ChatRoom(
      roomId: doc.id,
      buyerId: data['buyerId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      listingId: data['listingId'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? doc.id,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  /// 指定 uid がこのルームの当事者か。
  bool isParticipant(String? uid) => uid != null && (uid == buyerId || uid == sellerId);
}
