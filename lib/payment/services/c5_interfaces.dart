/// 学内情報共有システム — C5 外部連携・データアクセス処理部
/// インターフェース定義（C4 から参照する範囲のみ）
library;

import 'package:student_information_1/payment/models/transaction_models.dart';

/// C5 M4 ItemRepository のうち、C4 が利用するメソッド群。
abstract interface class ItemRepository {
  /// 対象教材のステータスを検証し「手続き中」へ更新、在庫を一時確保する。
  /// 例外: 既に売却/手続き中なら C4Exception(409)、ID 不存在なら 404、
  /// トランザクション競合がリトライ上限超過なら 503。
  Future<LockResult> lockItemForPurchase({
    required String listingId,
    required String buyerId,
  });

  /// 確保済みの在庫ロックを解除し、ステータスを「販売中」へロールバックする。
  Future<String> unlockItem({required String listingId});
}

/// C5 M6 PaymentGateway のうち、C4 M3 が利用するメソッド。
abstract interface class PaymentGatewayClient {
  /// Stripe へ PaymentIntent 生成を要求し、クライアントシークレットを取得する。
  /// 例外: 通信障害・無効パラメータ時は C4Exception(502)。
  Future<PaymentIntentResult> createPaymentIntent({
    required String listingId,
    required int amount,
    required String buyerUid,
  });
}
