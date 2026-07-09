/// 学内情報共有システム — C4 取引・決済処理部
/// M3 ゲートウェイ連携モジュール  担当: 木幡 陽介
library;

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';

/// ゲートウェイ連携モジュール。M2 の在庫ロック成功を受けて PaymentIntent を
/// 生成する。失敗時は在庫ロックを解除（ロールバック）してから 502 を送出。
class GatewayIntegrationModule {
  final PaymentGatewayClient _paymentGateway;
  final ItemRepository _itemRepository;

  const GatewayIntegrationModule({
    required PaymentGatewayClient paymentGateway,
    required ItemRepository itemRepository,
  })  : _paymentGateway = paymentGateway,
        _itemRepository = itemRepository;

  Future<PaymentIntentResult> createPaymentIntent({
    required String listingId,
  }) async {
    try {
      final result = await _paymentGateway.createPaymentIntent(
        listingId: listingId,
      );
      return result;
    } on C4Exception {
      await _rollbackLock(listingId);
      rethrow;
    } catch (e) {
      await _rollbackLock(listingId);
      throw C4Exception(502, '決済ゲートウェイとの連携に失敗しました。($e)');
    }
  }

  Future<void> _rollbackLock(String listingId) async {
    try {
      await _itemRepository.unlockItem(listingId: listingId);
    } catch (_) {
      // ロールバック失敗は致命的ではないため握りつぶす（要監視）。
    }
  }
}
