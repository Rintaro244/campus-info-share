/// 学内情報共有システム — C4 取引・決済処理部
/// 購入（譲渡）完了画面
///
/// 0円（無料譲渡）確定後に PaymentNavigator.goToPurchaseComplete から遷移する。
/// MaterialApp への route 登録（AppRoutes.purchaseComplete）は画面統合タスクで行い、
/// その際 settings.arguments（listingId: String）を本コンストラクタへ渡すこと。
library;

import 'package:flutter/material.dart';

import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';
import 'package:student_information_1/payment/ui/screens/chat_screen.dart';

/// 購入（譲渡）完了画面。
class PurchaseCompleteScreen extends StatelessWidget {
  /// 確定した教材の listingId（表示・デバッグ用。null 可）。
  final String? listingId;

  /// チャットルーム ID（= transactionId）。あれば「出品者と連絡を取る」導線を出す。
  final String? transactionId;

  const PurchaseCompleteScreen({
    super.key,
    this.listingId,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('取引完了')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text('譲渡が完了しました', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            const Text('教材の受け渡し方法は出品者と連絡を取ってください。'),
            // transactionId があればチャット導線を出す（= 上の案内文の回収）。
            if (transactionId != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(roomId: transactionId!),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('出品者と連絡を取る'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // W13 教材一覧（未登録ならホーム）まで戻る。
                Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == AppRoutes.itemList ||
                      route.isFirst,
                );
              },
              child: const Text('一覧へ戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
