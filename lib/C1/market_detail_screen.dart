// lib/C1/market_detail_screen.dart
//
// 教材詳細画面（C4 取引・決済処理部に統合）。
// listingId を受け取り items から最新の Item を取得して表示する。
// 「購入する / 無料で譲り受ける」で確認ダイアログ → c_pending_item_id をセット
// → W15 支払方法選択へ遷移し、以降は PurchaseFlowCoordinator が処理する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';
import 'package:student_information_1/payment/ui/widgets/item_price_label.dart';

class MarketDetailScreen extends ConsumerStatefulWidget {
  /// 表示対象の教材 ID（items のドキュメント ID）。
  final String listingId;

  const MarketDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends ConsumerState<MarketDetailScreen> {
  Item? _item;
  bool _isLoading = true;
  String? _errorMessage;

  /// 出品取消の実行中フラグ（多重タップ防止）。
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _reloadItem();
  }

  Future<void> _reloadItem() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final item = await ref
          .read(itemCatalogRepositoryProvider)
          .fetchItemById(widget.listingId);
      if (!mounted) return;
      setState(() => _item = item);
    } on C4Exception catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPurchasePressed(Item item) async {
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
        content: Text('「${item.displayTitle}」の購入手続きに進みますか？'),
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
    ref.read(pendingItemStoreProvider).pendingItemId = item.listingId;
    await Navigator.pushNamed(
      context,
      AppRoutes.paymentSelect,
      arguments: item,
    );
    // 支払フローから戻ってきたら最新化（購入完了で sold になっている等）。
    if (mounted) _reloadItem();
  }

  /// 出品取消（出品者本人 かつ on_sale のときのみ到達する）。
  Future<void> _onCancelListingPressed(Item item) async {
    // 重要操作は確認ダイアログを表示する（要求仕様書 §4.2）。
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('出品の取消'),
        content: Text('「${item.displayTitle}」の出品を取り消しますか？\n（この操作は取り消せません）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取り消す'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _deleting = true);
    // 画像は放置方針のため imageUrl は渡さない（Storage 削除を発火させない）。
    final ok = await ref
        .read(marketManagerProvider)
        .deleteProduct(item.listingId, null);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出品を取り消しました')),
      );
      // 一覧へ戻る（market_search_screen が戻り時に一覧を再取得する）。
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出品の取消に失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品詳細')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _reloadItem,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }
    final item = _item;
    if (item == null) {
      return const Center(child: Text('教材が見つかりませんでした。'));
    }
    return _buildContent(item);
  }

  Widget _buildContent(Item item) {
    final imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
    // 出品取消は「出品者本人」かつ「販売中(on_sale)」のときだけ表示（UI ガード。
    // Rules 側でも本人×on_sale のみ許可しているため二重で担保される）。
    final uid = ref.read(currentUidProvider);
    final canCancel = uid != null &&
        uid == item.sellerId &&
        item.status == ItemStatus.onSale;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品画像（Storage 連携までは未設定ならプレースホルダ）
          if (imageUrl != null)
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.black87, // 余白を黒にして画像を引き締める
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain, // 見切れ防止
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.menu_book, size: 64, color: Colors.grey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 価格（無料バッジ / ¥価格 / 価格未設定）
                ItemPriceLabel(price: item.price, fontSize: 26),
                const SizedBox(height: 8),
                // タイトル
                Text(
                  item.displayTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // タグ（販売ステータス・キャンパス・状態）
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(status: item.status),
                    if (item.campus != null)
                      Chip(
                        label: Text(item.campus!),
                        backgroundColor: Colors.blue[50],
                        labelStyle: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold),
                      ),
                    if (item.condition != null)
                      Chip(
                        label: Text(item.condition!),
                        backgroundColor: Colors.green[50],
                        labelStyle: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '商品の説明',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  item.description?.trim().isNotEmpty == true
                      ? item.description!
                      : '説明はまだ登録されていません。',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  '出品者: ${item.sellerId ?? '不明'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        item.canPurchase ? () => _onPurchasePressed(item) : null,
                    child: Text(
                      item.canPurchase
                          ? (item.isFree ? '無料で譲り受ける' : '購入する')
                          : 'この教材は現在購入できません',
                    ),
                  ),
                ),
                // 出品者本人向け: 出品取消（本人 × on_sale のときのみ）。
                if (canCancel) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _deleting ? null : () => _onCancelListingPressed(item),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        '出品を取り消す',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 販売ステータス表示（販売中 / 手続き中 / 売却済）。
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
