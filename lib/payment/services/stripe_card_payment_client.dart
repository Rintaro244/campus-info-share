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

  @override
  Widget buildCardInput() => const CardFormField();

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
    } on StripeException catch (e) {
      // カード拒否・入力不備・ユーザキャンセル等。402 で画面にエラー表示させる。
      throw C4Exception(
        402,
        e.error.localizedMessage ?? e.error.message ?? 'カード決済に失敗しました。',
      );
    } catch (e) {
      throw C4Exception(502, '決済処理に失敗しました。($e)');
    }
  }
}
