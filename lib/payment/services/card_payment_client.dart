/// 学内情報共有システム — C4 取引・決済処理部
/// カード決済クライアントの抽象（Stripe SDK 依存を1点に閉じ込めるための interface）
///
/// 画面・core はこの interface だけを参照し、テストでは Fake に差し替える。
/// 実 SDK（flutter_stripe）を import するのは具象 stripe_card_payment_client.dart のみ
/// （と main.dart の初期化）に閉じ込める。C4 が C5 を抽象で参照するのと同じ設計思想。
library;

import 'package:flutter/widgets.dart';

/// カード決済のクライアント抽象。
abstract interface class CardPaymentClient {
  /// カード情報入力ウィジェット（実装: Stripe のカードフィールド／Fake: ダミー）。
  Widget buildCardInput();

  /// [clientSecret] でカード決済を確定する。
  /// 成功で正常終了、失敗は C4Exception を投げる（画面はこれを捕まえて showError する）。
  ///
  /// 【重要】このメソッドの成功は「決済オーソリ OK の合図」でしかない。
  /// item を sold にする取引確定は Stripe Webhook（handleStripeWebhook→fulfillOrder）が
  /// 非同期に行うため、クライアント側からは fulfill / sold 化を一切呼ばない。
  Future<void> confirmPayment({required String clientSecret});
}
