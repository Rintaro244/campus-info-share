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
  /// buyerId は認証トークン、金額はサーバが items.price（正規価格）から算出する
  /// ため、クライアントから送るのは listingId のみ。
  /// 例外: 通信障害・無効パラメータ時は C4Exception(502)。
  Future<PaymentIntentResult> createPaymentIntent({required String listingId});
}

/// C5 のうち、0円（無料譲渡）確定 callable を呼ぶメソッド。
abstract interface class FreeTransferClient {
  /// 0円教材の譲渡を確定する（item を sold へ、取引記録を paid で作成）。
  /// 前提: M2 の在庫ロック（pending, buyerId=自分）を通過済みであること。
  /// 冪等: 既に本人へ確定済みならエラーにせず成功扱い。
  /// 例外: 404/409/400 等を C4Exception で送出。
  Future<String> fulfillFreeTransfer({required String listingId});
}
