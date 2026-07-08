/// 学内情報共有システム — C4 取引・決済処理部
/// W13 教材一覧画面
///
/// 販売中（on_sale）の教材だけを一覧表示する。
/// 画像は Storage 連携までプレースホルダ表示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  List<Item> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items =
          await ref.read(itemCatalogRepositoryProvider).fetchOnSaleItems();
      if (!mounted) return;
      setState(() => _items = items);
    } on C4Exception catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教材取引')),
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
              onPressed: _loadItems,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      // データなし画面は空白にしない（要求仕様書 §4.2）。
      return const Center(
        child: Text(
          '出品された教材はまだありません。\n出品されるとここに表示されます。',
          textAlign: TextAlign.center,
        ),
      );
    }
    // レスポンシブ対応（要求仕様書7章）: スマホ1列→タブレット2列→PC3列
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200 ? 3 : (width >= 600 ? 2 : 1);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 200,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) => _ItemCard(
            item: _items[index],
            onReturned: _loadItems,
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;

  /// 詳細から戻ってきたときの再読込（購入で status が変わるため）。
  final VoidCallback onReturned;

  const _ItemCard({required this.item, required this.onReturned});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(
            context,
            AppRoutes.itemDetail,
            arguments: item,
          );
          onReturned();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像プレースホルダ（Storage 連携までの暫定表示）
            Container(
              height: 96,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.menu_book, size: 40, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  ItemPriceLabel(price: item.price),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 価格表示（0円は「無料」バッジ、未設定は「価格未設定」）。W14 でも使う。
class ItemPriceLabel extends StatelessWidget {
  final int? price;
  final double fontSize;

  const ItemPriceLabel({super.key, required this.price, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final price = this.price;
    if (price == null) {
      return Text(
        '価格未設定',
        style: TextStyle(fontSize: fontSize, color: Colors.grey),
      );
    }
    if (price == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '無料',
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Text(
      '¥$price',
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
    );
  }
}
