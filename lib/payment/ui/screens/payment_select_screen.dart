/// 学内情報共有システム — C4 取引・決済処理部
/// W15 支払方法選択画面
///
/// 「確定」で PurchaseFlowCoordinator.confirmAndPay を1回呼ぶだけの薄い画面。
/// 在庫ロック・PaymentIntent 生成・0円分岐・遷移・エラー表示はすべて
/// Coordinator 側（実装済み）が行う。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/ui/screens/item_list_screen.dart';

/// 支払方法（今回はクレジットカードのみ実装。他は将来用）。
enum PaymentMethod { card }

class PaymentSelectScreen extends ConsumerStatefulWidget {
  final Item item;

  const PaymentSelectScreen({super.key, required this.item});

  @override
  ConsumerState<PaymentSelectScreen> createState() =>
      _PaymentSelectScreenState();
}

class _PaymentSelectScreenState extends ConsumerState<PaymentSelectScreen> {
  PaymentMethod _method = PaymentMethod.card;
  bool _isProcessing = false;

  Future<void> _onConfirmPressed() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    // 1秒以上かかりうる処理のためローディング必須（要求仕様書 §4.1）。
    setState(() => _isProcessing = true);
    try {
      // 成功時の遷移（カード入力 or 完了画面）も失敗時の差し戻しも
      // Coordinator が Navigator 経由で行う。
      await ref
          .read(purchaseFlowCoordinatorProvider)
          .confirmAndPay(buyerId: uid);
    } finally {
      // 失敗時は Coordinator が W14 まで pop するため dispose 済みのことがある。
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: const Text('支払い方法の選択')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 対象教材の要約
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(item.displayTitle),
                subtitle: const Text('表示価格（確定金額は手続き時に再取得します）'),
                trailing: ItemPriceLabel(price: item.price, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (item.isFree)
              const Text(
                'この教材は無料で譲り受けられます。\n「確定」を押すと譲渡が成立します。',
                style: TextStyle(fontSize: 14),
              )
            else ...[
              const Text(
                '支払い方法',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              RadioGroup<PaymentMethod>(
                groupValue: _method,
                onChanged: (v) =>
                    setState(() => _method = v ?? PaymentMethod.card),
                child: const RadioListTile<PaymentMethod>(
                  value: PaymentMethod.card,
                  title: Text('クレジットカード'),
                  subtitle: Text('Stripe による決済'),
                ),
              ),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.more_horiz),
                title: Text('その他の支払い方法（準備中）'),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isProcessing ? null : _onConfirmPressed,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(item.isFree ? '無料で譲り受ける（確定）' : '支払い方法を確定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
