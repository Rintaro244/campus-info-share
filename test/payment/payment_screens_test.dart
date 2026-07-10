/// C4 決済UI（教材詳細 → 支払方法選択 → confirmAndPay）の画面フロー widget テスト。
/// Riverpod の override で Firebase 依存を Fake に差し替え、
/// MarketDetailScreen（詳細）→ W15（支払選択）→ Coordinator の遷移を実画面で検証する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_information_1/C1/market_detail_screen.dart';
import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/payment_integration.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';
import 'package:student_information_1/payment/services/card_payment_client.dart';
import 'package:student_information_1/payment/services/in_memory_pending_item_store.dart';
import 'package:student_information_1/payment/services/item_catalog_repository.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';

class FakeItemCatalogRepository implements ItemCatalogRepository {
  final List<Item> items;

  FakeItemCatalogRepository(this.items);

  @override
  Future<List<Item>> fetchOnSaleItems() async =>
      items.where((i) => i.isOnSale).toList();

  @override
  Future<Item> fetchItemById(String listingId) async =>
      items.firstWhere(
        (i) => i.listingId == listingId,
        orElse: () => throw const C4Exception(404, '対象の教材が見つかりません。'),
      );
}

class FakeItemRepository implements ItemRepository {
  final int amount;
  int unlockCalls = 0;

  FakeItemRepository({required this.amount});

  @override
  Future<LockResult> lockItemForPurchase({
    required String listingId,
    required String buyerId,
  }) async =>
      LockResult(status: 'locked', amount: amount);

  @override
  Future<String> unlockItem({required String listingId}) async {
    unlockCalls++;
    return 'unlocked';
  }
}

class FakePaymentGateway implements PaymentGatewayClient {
  @override
  Future<PaymentIntentResult> createPaymentIntent({
    required String listingId,
  }) async =>
      const PaymentIntentResult(
        clientSecret: 'cs_test_123',
        paymentIntentId: 'pi_test_123',
      );
}

class FakeFreeTransferClient implements FreeTransferClient {
  final C4Exception? transferError;
  int calls = 0;

  FakeFreeTransferClient({this.transferError});

  @override
  Future<String> fulfillFreeTransfer({required String listingId}) async {
    calls++;
    final error = transferError;
    if (error != null) throw error;
    return 'fulfilled';
  }
}

/// カード決済クライアントの Fake。ここでは card_entry 画面がクラッシュせず描画できれば
/// 十分（このファイルのテストは決済実行までは踏み込まない）。入力欄はダミーを返す。
class FakeCardPaymentClient implements CardPaymentClient {
  @override
  Widget buildCardInput() => const SizedBox.shrink();

  @override
  Future<void> confirmPayment({required String clientSecret}) async {}
}

const paidItem = Item(
  listingId: 'item_paid',
  title: '線形代数の教科書',
  description: '書き込みなし。',
  price: 1500,
  status: ItemStatus.onSale,
  sellerId: 'seller1',
);

const freeItem = Item(
  listingId: 'item_free',
  title: '無料の過去問集',
  price: 0,
  status: ItemStatus.onSale,
  sellerId: 'seller1',
);

/// テスト用アプリを組み立てる。main.dart と同じ統合ポイント（onGeneratePaymentRoute）
/// を使い、詳細画面を home に置いて購入フローを検証する。
Widget buildTestApp({
  required String listingId,
  required List<Item> catalogItems,
  required FakeItemRepository itemRepository,
  required InMemoryPendingItemStore pendingStore,
  FakeFreeTransferClient? freeTransfer,
}) {
  final navKey = GlobalKey<NavigatorState>();
  final msgKey = GlobalKey<ScaffoldMessengerState>();
  return ProviderScope(
    overrides: [
      currentUidProvider.overrideWithValue('buyer1'),
      itemCatalogRepositoryProvider
          .overrideWithValue(FakeItemCatalogRepository(catalogItems)),
      itemRepositoryProvider.overrideWithValue(itemRepository),
      paymentGatewayClientProvider.overrideWithValue(FakePaymentGateway()),
      freeTransferClientProvider
          .overrideWithValue(freeTransfer ?? FakeFreeTransferClient()),
      pendingItemStoreProvider.overrideWithValue(pendingStore),
      cardPaymentClientProvider.overrideWithValue(FakeCardPaymentClient()),
      paymentNavigatorProvider.overrideWithValue(
        FlutterPaymentNavigator(navigatorKey: navKey, messengerKey: msgKey),
      ),
    ],
    child: MaterialApp(
      navigatorKey: navKey,
      scaffoldMessengerKey: msgKey,
      onGenerateRoute: onGeneratePaymentRoute,
      home: MarketDetailScreen(listingId: listingId),
    ),
  );
}

void main() {
  testWidgets('詳細: 有償教材を表示し購入ボタンが活性', (tester) async {
    await tester.pumpWidget(buildTestApp(
      listingId: 'item_paid',
      catalogItems: [paidItem],
      itemRepository: FakeItemRepository(amount: 1500),
      pendingStore: InMemoryPendingItemStore(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('商品詳細'), findsOneWidget);
    expect(find.text('線形代数の教科書'), findsOneWidget);
    expect(find.text('書き込みなし。'), findsOneWidget);
    expect(find.text('¥1500'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '購入する'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('詳細: 0円教材は無料バッジと「無料で譲り受ける」ボタンを表示', (tester) async {
    await tester.pumpWidget(buildTestApp(
      listingId: 'item_free',
      catalogItems: [freeItem],
      itemRepository: FakeItemRepository(amount: 0),
      pendingStore: InMemoryPendingItemStore(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('無料'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '無料で譲り受ける'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('詳細→W15: 確認ダイアログを経て支払選択へ、pendingItemId がセットされる',
      (tester) async {
    final pendingStore = InMemoryPendingItemStore();
    await tester.pumpWidget(buildTestApp(
      listingId: 'item_paid',
      catalogItems: [paidItem],
      itemRepository: FakeItemRepository(amount: 1500),
      pendingStore: pendingStore,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, '購入する'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '購入する'));
    await tester.pumpAndSettle();

    // 重要操作の確認ダイアログ（要求仕様書 §4.2）
    expect(find.text('購入手続き'), findsOneWidget);
    await tester.tap(find.text('進む'));
    await tester.pumpAndSettle();

    expect(find.text('支払い方法の選択'), findsOneWidget);
    expect(find.text('クレジットカード'), findsOneWidget);
    expect(pendingStore.pendingItemId, 'item_paid');
  });

  testWidgets('W15(有償): 確定で clientSecret を受領しカード入力画面へ', (tester) async {
    await tester.pumpWidget(buildTestApp(
      listingId: 'item_paid',
      catalogItems: [paidItem],
      itemRepository: FakeItemRepository(amount: 1500),
      pendingStore: InMemoryPendingItemStore(),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, '購入する'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '購入する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進む'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('支払い方法を確定'));
    await tester.pumpAndSettle();

    expect(find.text('カード情報の入力'), findsOneWidget);
    expect(find.text('お支払い金額: ¥1500'), findsOneWidget);
  });

  testWidgets('W15(0円): 確定で譲渡が成立し完了画面へ、pendingItemId がクリアされる',
      (tester) async {
    final pendingStore = InMemoryPendingItemStore();
    final freeTransfer = FakeFreeTransferClient();
    await tester.pumpWidget(buildTestApp(
      listingId: 'item_free',
      catalogItems: [freeItem],
      itemRepository: FakeItemRepository(amount: 0),
      pendingStore: pendingStore,
      freeTransfer: freeTransfer,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, '無料で譲り受ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '無料で譲り受ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進む'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('無料で譲り受ける（確定）'));
    await tester.pumpAndSettle();

    expect(freeTransfer.calls, 1);
    expect(find.text('譲渡が完了しました'), findsOneWidget);
    expect(pendingStore.pendingItemId, isNull);
  });

  testWidgets('W15(0円)失敗: エラー表示し詳細へ戻り、ロックが解除される', (tester) async {
    final itemRepository = FakeItemRepository(amount: 0);
    await tester.pumpWidget(buildTestApp(
      listingId: 'item_free',
      catalogItems: [freeItem],
      itemRepository: itemRepository,
      pendingStore: InMemoryPendingItemStore(),
      freeTransfer: FakeFreeTransferClient(
        transferError: const C4Exception(409, 'この教材は既に確定済みです。'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, '無料で譲り受ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '無料で譲り受ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進む'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('無料で譲り受ける（確定）'));
    await tester.pumpAndSettle();

    // 詳細画面へ差し戻され、SnackBar でエラーが出る
    expect(find.text('商品詳細'), findsOneWidget);
    expect(find.textContaining('確定済み'), findsOneWidget);
    expect(itemRepository.unlockCalls, 1);
  });
}
