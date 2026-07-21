/// 学内情報共有システム — C4 取引・決済処理部
/// CardPaymentClient の Stripe 具象。
///
/// 【設計・厳守】flutter_stripe を import するのは（main.dart の初期化を除き）
/// このファイルだけに閉じ込める。画面・core・テストは SDK 非依存を保つ。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/card_payment_client.dart';

/// flutter_stripe を用いた CardPaymentClient の実装。
class StripeCardPaymentClient implements CardPaymentClient {
  const StripeCardPaymentClient();

  /// カード入力欄。CardFormField ではなく CardField を使うこと（Web で必須）。
  /// CardFormField は kIsWeb 分岐を持たず、android/iOS 以外では
  /// UnsupportedError('Unsupported platform view') を投げて赤画面になる。
  /// CardField は内部で kIsWeb を見て flutter_stripe_web の WebCardField
  /// （HtmlElementView 経由の Stripe Elements）に切り替える。
  /// 高さは CardField が内部の SizedBox で確定するため外側で与えない。
  @override
  Widget buildCardInput() => const CardField();

  @override
  Future<void> confirmPayment({required String clientSecret}) async {
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
      // 成功 = 決済オーソリ OK の合図のみ。ここでは item を sold にしない・fulfill を
      // 呼ばない。取引確定（items.status=sold / transactions.status=paid）は Stripe の
      // Webhook（handleStripeWebhook→fulfillOrder）が非同期に行う（二重確定を避ける）。
    } on StripeConfigException {
      // publishable key 未設定。flutter_stripe が投げるのはこの1条件だけで
      // （stripe.dart の publishableKey ゲッター）、初回決済時に必ず露見する。
      // カード拒否と違い再試行しても直らないため、起動方法を促す文言にする。
      throw const C4Exception(
        500,
        'カード決済が初期化されていません。STRIPE_PUBLISHABLE_KEY を指定して起動してください。',
      );
    } on StripeError catch (e) {
      // Web(flutter_stripe_web) はカード拒否等で StripeError を投げる
      // （web_stripe.dart の confirmPayment）。StripeException とは別クラスで、
      // Stripe.instance も `on StripeError { rethrow; }` で変換せず素通しするため、
      // 個別に捕まえないと下の総取り catch に落ちて 502 になる。
      throw C4Exception(
        402,
        e.message.isNotEmpty ? e.message : 'カード決済に失敗しました。',
      );
    } on StripeException catch (e) {
      // ネイティブ(iOS/Android)はこちら。カード拒否・入力不備・ユーザキャンセル等。
      // 将来のスマホ展開に備えて残す（Web では発生しない）。
      throw C4Exception(
        402,
        e.error.localizedMessage ?? e.error.message ?? 'カード決済に失敗しました。',
      );
    } catch (e) {
      throw C4Exception(502, '決済処理に失敗しました。($e)');
    }
  }
}
