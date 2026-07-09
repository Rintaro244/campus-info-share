/// 学内情報共有システム — C4 取引・決済処理部
/// 決済カード入力画面（プレースホルダ）
///
/// 実決済（flutter_stripe / Stripe.js での confirmPayment）は未実装。
/// 現段階の責務は「clientSecret を受領して遷移できた」ことの確認まで。
/// 実装時は CardEntryArgs.clientSecret を Stripe SDK に渡す。
library;

import 'package:flutter/material.dart';

import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';

class CardEntryScreen extends StatelessWidget {
  final CardEntryArgs args;

  const CardEntryScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カード情報の入力')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.credit_card, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'お支払い金額: ¥${args.amount}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '決済ID: ${args.paymentIntentId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                'カード入力フォーム（Stripe 連携）は準備中です。\n決済の準備（clientSecret の受領）までが完了しています。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == AppRoutes.itemList ||
                      route.isFirst,
                ),
                child: const Text('一覧へ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
