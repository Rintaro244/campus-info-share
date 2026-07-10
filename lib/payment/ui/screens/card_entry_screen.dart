/// 学内情報共有システム — C4 取引・決済処理部
/// 決済カード入力画面
///
/// clientSecret（createPaymentIntent で受領済み）を CardPaymentClient に渡してカード決済を実行する。
/// 決済成功はあくまで「オーソリ OK の合図」であり、item を sold にする取引確定は
/// Stripe Webhook（handleStripeWebhook→fulfillOrder）が非同期に行う。
/// → この画面からは fulfill / sold 化を一切呼ばない（二重確定を避ける）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';

class CardEntryScreen extends ConsumerStatefulWidget {
  final CardEntryArgs args;

  const CardEntryScreen({super.key, required this.args});

  @override
  ConsumerState<CardEntryScreen> createState() => _CardEntryScreenState();
}

class _CardEntryScreenState extends ConsumerState<CardEntryScreen> {
  /// 決済処理中フラグ。二重送信防止とローディング表示に使う。
  bool _processing = false;

  Future<void> _onPay() async {
    if (_processing) return; // 二重送信防止（処理中の連打を無視）。
    setState(() => _processing = true);

    final args = widget.args;
    try {
      await ref
          .read(cardPaymentClientProvider)
          .confirmPayment(clientSecret: args.clientSecret);
      if (!mounted) return;
      // オーソリ OK。取引確定（items.status=sold / transactions.status=paid）は
      // Webhook が非同期に行うため、ここでは完了画面へ進むだけ。fulfill は呼ばない。
      // 有償フローの transactionId は paymentIntentId（webhook が transactions/{pi} を作る）。
      ref.read(paymentNavigatorProvider).goToPurchaseComplete(
            listingId: args.listingId,
            transactionId: args.paymentIntentId,
          );
    } on C4Exception catch (e) {
      if (!mounted) return;
      ref.read(paymentNavigatorProvider).showError(code: e.code, message: e.message);
      setState(() => _processing = false); // 同じ画面で再試行できるよう再活性。
    } catch (e) {
      if (!mounted) return;
      ref
          .read(paymentNavigatorProvider)
          .showError(code: 502, message: '決済処理に失敗しました。');
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return Scaffold(
      appBar: AppBar(title: const Text('カード情報の入力')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'お支払い金額: ¥${args.amount}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // カード入力欄（実装: Stripe のカードフィールド／テスト: Fake のダミー）。
              ref.read(cardPaymentClientProvider).buildCardInput(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _processing ? null : _onPay,
                child: _processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('支払う'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
