/// C4 出品取消（items delete）の widget テスト。
/// market_detail_screen の「出品を取り消す」ボタンの表示条件（本人×on_sale）と、
/// 確認ダイアログ→deleteProduct(listingId, null) 呼び出し→成功時 pop / 失敗時エラー表示を検証する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_information_1/C1/market_detail_screen.dart';
import 'package:student_information_1/C3/market_manager.dart';
import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/services/item_catalog_repository.dart';

class FakeItemCatalogRepository implements ItemCatalogRepository {
  final Item item;
  FakeItemCatalogRepository(this.item);

  @override
  Future<Item> fetchItemById(String listingId) async => item;

  @override
  Future<List<Item>> fetchOnSaleItems() async => [item];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMarketManager implements MarketManager {
  final bool result;
  final List<List<Object?>> deleteCalls = [];

  FakeMarketManager({this.result = true});

  @override
  Future<bool> deleteProduct(String docId, String? imageUrl) async {
    deleteCalls.add([docId, imageUrl]);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// home の上に詳細画面を push できるスタブ。pop の検証に使う。
class _HomeStub extends StatelessWidget {
  final String listingId;
  const _HomeStub({required this.listingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MarketDetailScreen(listingId: listingId),
            ),
          ),
          child: const Text('OPEN_DETAIL'),
        ),
      ),
    );
  }
}

Widget buildApp({
  required Item item,
  required String uid,
  required FakeMarketManager marketManager,
}) {
  return ProviderScope(
    overrides: [
      currentUidProvider.overrideWithValue(uid),
      itemCatalogRepositoryProvider
          .overrideWithValue(FakeItemCatalogRepository(item)),
      marketManagerProvider.overrideWithValue(marketManager),
    ],
    child: MaterialApp(home: _HomeStub(listingId: item.listingId)),
  );
}

const _sellerUid = 'seller1';

Item _item({required String status}) => Item(
      listingId: 'item_x',
      title: 'テスト教材',
      price: 1000,
      status: status,
      sellerId: _sellerUid,
    );

/// _HomeStub → 詳細画面へ遷移する。
Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.text('OPEN_DETAIL'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('① 本人 × on_sale なら「出品を取り消す」ボタンが表示される', (tester) async {
    await tester.pumpWidget(buildApp(
      item: _item(status: ItemStatus.onSale),
      uid: _sellerUid,
      marketManager: FakeMarketManager(),
    ));
    await _openDetail(tester);

    expect(find.text('出品を取り消す'), findsOneWidget);
  });

  testWidgets('② 他人（uid != sellerId）ならボタンは表示されない', (tester) async {
    await tester.pumpWidget(buildApp(
      item: _item(status: ItemStatus.onSale),
      uid: 'someone_else',
      marketManager: FakeMarketManager(),
    ));
    await _openDetail(tester);

    expect(find.text('出品を取り消す'), findsNothing);
  });

  testWidgets('③ 本人でも pending ならボタンは表示されない', (tester) async {
    await tester.pumpWidget(buildApp(
      item: _item(status: ItemStatus.pending),
      uid: _sellerUid,
      marketManager: FakeMarketManager(),
    ));
    await _openDetail(tester);

    expect(find.text('出品を取り消す'), findsNothing);
  });

  testWidgets('③b 本人でも sold ならボタンは表示されない', (tester) async {
    await tester.pumpWidget(buildApp(
      item: _item(status: ItemStatus.sold),
      uid: _sellerUid,
      marketManager: FakeMarketManager(),
    ));
    await _openDetail(tester);

    expect(find.text('出品を取り消す'), findsNothing);
  });

  testWidgets('④ 確認ダイアログ→取り消す→deleteProduct(listingId, null) が呼ばれ成功で pop',
      (tester) async {
    final manager = FakeMarketManager(result: true);
    await tester.pumpWidget(buildApp(
      item: _item(status: ItemStatus.onSale),
      uid: _sellerUid,
      marketManager: manager,
    ));
    await _openDetail(tester);
    expect(find.text('商品詳細'), findsOneWidget); // 詳細画面にいる

    // ボタンは画面下端でスクロール圏外のことがあるため可視化してから押す。
    await tester.ensureVisible(find.text('出品を取り消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('出品を取り消す'));
    await tester.pumpAndSettle();
    // 確認ダイアログの「取り消す」を押す。
    await tester.tap(find.widgetWithText(FilledButton, '取り消す'));
    await tester.pumpAndSettle();

    // 画像は放置方針: 第2引数は null。
    expect(manager.deleteCalls, hasLength(1));
    expect(manager.deleteCalls.single, ['item_x', null]);
    // 成功で詳細が pop され、home に戻っている。
    expect(find.text('商品詳細'), findsNothing);
    expect(find.text('OPEN_DETAIL'), findsOneWidget);
    expect(find.text('出品を取り消しました'), findsOneWidget);
  });

  testWidgets('⑤ deleteProduct が false なら失敗表示、画面は pop しない', (tester) async {
    final manager = FakeMarketManager(result: false);
    await tester.pumpWidget(buildApp(
      item: _item(status: ItemStatus.onSale),
      uid: _sellerUid,
      marketManager: manager,
    ));
    await _openDetail(tester);

    await tester.ensureVisible(find.text('出品を取り消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('出品を取り消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '取り消す'));
    await tester.pumpAndSettle();

    expect(manager.deleteCalls, hasLength(1));
    // 失敗: 詳細画面のまま。
    expect(find.text('商品詳細'), findsOneWidget);
    expect(find.text('出品の取消に失敗しました'), findsOneWidget);
  });
}
