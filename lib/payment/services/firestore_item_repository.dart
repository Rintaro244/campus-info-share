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
const String _fieldSellerId = 'sellerId';
const String _statusOnSale = 'on_sale';
const String _statusPending = 'pending';

/// 在庫ロックの失敗理由。トランザクション内から例外を投げずに持ち帰るために使う
/// （Web では runTransaction 内の例外が JS を跨いで型を失うため）。
enum _LockFailure { notFound, selfPurchase, notOnSale, invalidPrice }

/// 在庫ロックのトランザクション結果。[failure] が null なら成功で [amount] が入る。
class _LockOutcome {
  final _LockFailure? failure;
  final int? amount;

  const _LockOutcome(this.failure) : amount = null;
  const _LockOutcome.locked(this.amount) : failure = null;
}

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
    final _LockOutcome outcome;
    try {
      // 【重要】このコールバックの中で例外を投げてはいけない。
      // Web では runTransaction が JS の Promise を跨ぐため、中で投げた Dart 例外は
      // RethrownDartError に化けて型が失われ、呼び出し側の `on C4Exception` を
      // 素通りして未捕捉になる（＝画面に何も出ない）。
      // 戻り値は Dart のクロージャ経由で渡るため型が保たれる。
      // よって「判定結果を返す」→「トランザクションの外で例外に変換する」形にする。
      outcome = await _firestore.runTransaction<_LockOutcome>((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          return const _LockOutcome(_LockFailure.notFound);
        }
        final data = snap.data()!;
        // 出品者本人の購入を状態チェックより先に弾く。
        // Rules の isLock() も uid != sellerId を要求するが、そちらに落ちると
        // permission-denied → 409「この操作は許可されていません。」という汎用文言になり、
        // 理由がユーザーに伝わらない（かつ「手続き中」の 409 と区別できない）。
        // 自分の教材が pending のときも、伝えるべきは「自分の商品だから買えない」の方。
        if (data[_fieldSellerId] == buyerId) {
          return const _LockOutcome(_LockFailure.selfPurchase);
        }
        if (data[_fieldStatus] != _statusOnSale) {
          // 既に手続き中 or 売却済。
          return const _LockOutcome(_LockFailure.notOnSale);
        }
        final price = data[_fieldPrice];
        if (price is! int) {
          return const _LockOutcome(_LockFailure.invalidPrice);
        }
        tx.update(docRef, {
          _fieldStatus: _statusPending,
          _fieldBuyerId: buyerId,
        });
        return _LockOutcome.locked(price);
      });
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }

    switch (outcome.failure) {
      case _LockFailure.notFound:
        throw const C4Exception(404, '対象の教材が見つかりません。');
      case _LockFailure.selfPurchase:
        throw const C4Exception(403, '自分が出品した教材は購入できません。');
      case _LockFailure.notOnSale:
        throw const C4Exception(409, 'この教材は現在購入できません（売却済または手続き中）。');
      case _LockFailure.invalidPrice:
        throw const C4Exception(500, '教材の価格情報が不正です。');
      case null:
        return LockResult(status: 'locked', amount: outcome.amount!);
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
