/// 学内情報共有システム — C4 取引・決済処理部
/// W14 教材詳細画面
///
/// 一覧から Item を受け取り、表示時に最新を再取得する（status が
/// 変わっている可能性があるため）。「購入する」で確認ダイアログを出し、
/// c_pending_item_id をセットして W15 へ遷移する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';
import 'package:student_information_1/payment/ui/screens/item_list_screen.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final Item item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  late Item _item;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _reloadItem();
  }

  Future<void> _reloadItem() async {
    setState(() => _errorMessage = null);
    try {
      final item = await ref
          .read(itemCatalogRepositoryProvider)
          .fetchItemById(_item.listingId);
      if (!mounted) return;
      setState(() => _item = item);
    } on C4Exception catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  Future<void> _onPurchasePressed() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    // 重要操作は確認ダイアログを表示する（要求仕様書 §4.2）。
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('購入手続き'),
        content: Text(
          '「${_item.displayTitle}」の購入手続きに進みますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('進む'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    // 外部変数 c_pending_item_id をセットしてから W15 へ。
    ref.read(pendingItemStoreProvider).pendingItemId = _item.listingId;
    await Navigator.pushNamed(
      context,
      AppRoutes.paymentSelect,
      arguments: _item,
    );
    // 支払フローから戻ってきたら最新化（購入完了で sold になっている等）。
    if (mounted) _reloadItem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教材詳細')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            // 画像プレースホルダ（Storage 連携までの暫定表示）
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.menu_book, size: 64, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _item.displayTitle,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ItemPriceLabel(price: _item.price, fontSize: 18),
            const SizedBox(height: 8),
            _StatusChip(status: _item.status),
            const SizedBox(height: 16),
            Text(
              _item.description?.trim().isNotEmpty == true
                  ? _item.description!
                  : '説明はまだ登録されていません。',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              '出品者: ${_item.sellerId ?? '不明'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _item.canPurchase ? _onPurchasePressed : null,
                child: Text(
                  _item.canPurchase
                      ? (_item.isFree ? '無料で譲り受ける' : '購入する')
                      : 'この教材は現在購入できません',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ItemStatus.onSale => ('販売中', Colors.blue),
      ItemStatus.pending => ('手続き中', Colors.orange),
      ItemStatus.sold => ('売却済', Colors.grey),
      _ => ('不明', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
