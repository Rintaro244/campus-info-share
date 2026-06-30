/// 学内情報共有システム — C5 外部連携・データアクセス処理部
/// ItemRepository の Firestore 具象実装（C4 が利用する範囲）
///
/// 在庫ロックは Cloud Functions の Callable 化はせず、Firestore Security Rules
/// （firestore.rules）で保護する方針。本実装はそのルールに準拠した形で update する。
///   - lockItemForPurchase: status 'on_sale' -> 'pending'、buyerId に自分の uid をセット
///   - unlockItem:          status 'pending' -> 'on_sale'、buyerId をクリア（保持者本人のみ）
/// status -> 'sold' はここでは行わない（サーバ M5 fulfill の Admin SDK のみ）。
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';

/// items スキーマの確定値（functions/src/constants.ts と一致させること）。
const String _itemsCollection = 'items';
const String _fieldStatus = 'status';
const String _fieldPrice = 'price';
const String _fieldBuyerId = 'buyerId';
const String _statusOnSale = 'on_sale';
const String _statusPending = 'pending';

/// ItemRepository の Firestore 具象。
class FirestoreItemRepository implements ItemRepository {
  final FirebaseFirestore _firestore;

  FirestoreItemRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection(_itemsCollection);

  @override
  Future<LockResult> lockItemForPurchase({
    required String listingId,
    required String buyerId,
  }) async {
    // 注意: buyerId は必ずサインイン中ユーザーの uid と一致させること。
    // firestore.rules が `request.resource.data.buyerId == request.auth.uid` を要求するため、
    // 不一致だと permission-denied になる。
    final docRef = _items.doc(listingId);
    try {
      return await _firestore.runTransaction<LockResult>((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          throw const C4Exception(404, '対象の教材が見つかりません。');
        }
        final data = snap.data()!;
        if (data[_fieldStatus] != _statusOnSale) {
          // 既に手続き中 or 売却済。
          throw const C4Exception(409, 'この教材は現在購入できません（売却済または手続き中）。');
        }
        final price = data[_fieldPrice];
        if (price is! int) {
          throw const C4Exception(500, '教材の価格情報が不正です。');
        }
        tx.update(docRef, {
          _fieldStatus: _statusPending,
          _fieldBuyerId: buyerId,
        });
        return LockResult(status: 'locked', amount: price);
      });
    } on C4Exception {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }
  }

  @override
  Future<String> unlockItem({required String listingId}) async {
    // ロック保持者本人のセッションでのみ成功する（Rules で担保）。
    try {
      await _items.doc(listingId).update({
        _fieldStatus: _statusOnSale,
        _fieldBuyerId: FieldValue.delete(),
      });
      return 'unlocked';
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }
  }

  /// FirebaseException を C4Exception（設計書のステータスコード）へ写像する。
  C4Exception _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'aborted':
      case 'failed-precondition':
      case 'unavailable':
        // トランザクション競合のリトライ上限超過・一時的障害。
        return const C4Exception(503, '混雑のため処理できませんでした。時間をおいて再試行してください。');
      case 'permission-denied':
        // Rules で拒否（未ログイン・他者のロック・不正な状態遷移など）。
        return const C4Exception(409, 'この操作は許可されていません。');
      default:
        return C4Exception(500, 'データアクセスでエラーが発生しました。(${e.code})');
    }
  }
}
