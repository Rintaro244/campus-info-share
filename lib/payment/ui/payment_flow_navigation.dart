/// 学内情報共有システム — C4 取引・決済処理部
/// 購入フロー コーディネータ（M2 → M3 連携 + 画面遷移）
library;

import 'package:student_information_1/payment/m2_purchase_control.dart';
import 'package:student_information_1/payment/m3_gateway_integration.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';

/// 画面遷移の抽象。Flutter の Navigator を直接持たず UI 層へ委譲する。
abstract interface class PaymentNavigator {
  void goToCardEntry({
    required String clientSecret,
    required String paymentIntentId,
    required int amount,
    required String listingId,
  });
  /// 購入（譲渡）完了画面へ遷移する。
  /// [transactionId] は完了画面の「出品者と連絡を取る」導線（= chats/{roomId}）に使う。
  /// 0円フローは `free_<listingId>`、将来の有償フローは `pi.id` を渡す想定（汎用）。
  void goToPurchaseComplete({required String listingId, String? transactionId});
  void backToItemDetail({required String reason});
  void showError({required int code, required String message});
}

/// 外部変数 c_pending_item_id を読み書きする抽象。
abstract interface class PendingItemStore {
  String? get pendingItemId;
  set pendingItemId(String? value);
}

/// 購入フロー コーディネータ。W15「支払い方法を確定」押下時に呼ばれ、
/// M2 で在庫ロック、M3 で PaymentIntent 生成、成功で決済画面へ遷移する。
class PurchaseFlowCoordinator {
  final PurchaseControlModule _m2;
  final GatewayIntegrationModule _m3;
  final FreeTransferClient _freeTransfer;
  final ItemRepository _itemRepository;
  final PaymentNavigator _navigator;
  final PendingItemStore _pendingStore;

  const PurchaseFlowCoordinator({
    required PurchaseControlModule m2,
    required GatewayIntegrationModule m3,
    required FreeTransferClient freeTransfer,
    required ItemRepository itemRepository,
    required PaymentNavigator navigator,
    required PendingItemStore pendingStore,
  })  : _m2 = m2,
        _m3 = m3,
        _freeTransfer = freeTransfer,
        _itemRepository = itemRepository,
        _navigator = navigator,
        _pendingStore = pendingStore;

  Future<PurchaseSession> confirmAndPay({required String buyerId}) async {
    final listingId = _pendingStore.pendingItemId;
    if (listingId == null || listingId.isEmpty) {
      _navigator.backToItemDetail(reason: '購入対象が選択されていません。');
      return const PurchaseSession(
        stage: PurchaseStage.aborted,
        listingId: '',
      );
    }

    final LockResult lock;
    try {
      lock = await _m2.initiatePurchase(
        buyerId: buyerId,
        listingId: listingId,
      );
    } on C4Exception catch (e) {
      _navigator.showError(code: e.code, message: e.message);
      _navigator.backToItemDetail(reason: e.message);
      return PurchaseSession(
        stage: PurchaseStage.aborted,
        listingId: listingId,
      );
    }

    // 0円（無料譲渡）: Stripe は amount=0 の PaymentIntent を作れないため、
    // M3 を経由せず専用 callable で直接確定する（ロック済みが前提）。
    if (lock.amount == 0) {
      return _completeFreeTransfer(listingId);
    }

    final PaymentIntentResult intent;
    try {
      intent = await _m3.createPaymentIntent(listingId: listingId);
    } on C4Exception catch (e) {
      _navigator.showError(code: e.code, message: e.message);
      _navigator.backToItemDetail(reason: e.message);
      return PurchaseSession(
        stage: PurchaseStage.aborted,
        listingId: listingId,
      );
    }

    _navigator.goToCardEntry(
      clientSecret: intent.clientSecret,
      paymentIntentId: intent.paymentIntentId,
      amount: lock.amount,
      listingId: listingId,
    );

    return PurchaseSession(
      stage: PurchaseStage.readyForPayment,
      listingId: listingId,
      amount: lock.amount,
      clientSecret: intent.clientSecret,
      paymentIntentId: intent.paymentIntentId,
    );
  }

  /// 0円（無料譲渡）の確定。失敗時は在庫ロックを解除して W14 へ戻す。
  Future<PurchaseSession> _completeFreeTransfer(String listingId) async {
    try {
      await _freeTransfer.fulfillFreeTransfer(listingId: listingId);
    } on C4Exception catch (e) {
      return _abortFreeTransfer(listingId, e);
    } catch (e) {
      return _abortFreeTransfer(
        listingId,
        C4Exception(502, '無料譲渡の確定に失敗しました。($e)'),
      );
    }

    onPurchaseCompleted();
    // 0円フローの transactionId は functions 側 freeTransactionId() と一致させる（free_<listingId>）。
    _navigator.goToPurchaseComplete(
      listingId: listingId,
      transactionId: 'free_$listingId',
    );
    return PurchaseSession(
      stage: PurchaseStage.completedFree,
      listingId: listingId,
      amount: 0,
    );
  }

  Future<PurchaseSession> _abortFreeTransfer(
    String listingId,
    C4Exception e,
  ) async {
    await _rollbackLock(listingId);
    _navigator.showError(code: e.code, message: e.message);
    _navigator.backToItemDetail(reason: e.message);
    return PurchaseSession(
      stage: PurchaseStage.aborted,
      listingId: listingId,
    );
  }

  Future<void> _rollbackLock(String listingId) async {
    try {
      await _itemRepository.unlockItem(listingId: listingId);
    } catch (_) {
      // ロールバック失敗は致命的ではないため握りつぶす。
    }
  }

  /// 購入完了時に外部変数 c_pending_item_id をクリアする。
  void onPurchaseCompleted() {
    _pendingStore.pendingItemId = null;
  }
}
