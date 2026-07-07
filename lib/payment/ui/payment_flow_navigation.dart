/// 学内情報共有システム — C4 取引・決済処理部
/// 購入フロー コーディネータ（M2 → M3 連携 + 画面遷移）
library;

import 'package:student_information_1/payment/m2_purchase_control.dart';
import 'package:student_information_1/payment/m3_gateway_integration.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';

/// 画面遷移の抽象。Flutter の Navigator を直接持たず UI 層へ委譲する。
abstract interface class PaymentNavigator {
  void goToCardEntry({
    required String clientSecret,
    required String paymentIntentId,
    required int amount,
  });
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
  final PaymentNavigator _navigator;
  final PendingItemStore _pendingStore;

  const PurchaseFlowCoordinator({
    required PurchaseControlModule m2,
    required GatewayIntegrationModule m3,
    required PaymentNavigator navigator,
    required PendingItemStore pendingStore,
  })  : _m2 = m2,
        _m3 = m3,
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

    final PaymentIntentResult intent;
    try {
      intent = await _m3.createPaymentIntent(
        listingId: listingId,
        amount: lock.amount,
        buyerId: buyerId,
      );
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
    );

    return PurchaseSession(
      stage: PurchaseStage.readyForPayment,
      listingId: listingId,
      amount: lock.amount,
      clientSecret: intent.clientSecret,
      paymentIntentId: intent.paymentIntentId,
    );
  }

  /// 購入完了時に外部変数 c_pending_item_id をクリアする。
  void onPurchaseCompleted() {
    _pendingStore.pendingItemId = null;
  }
}
