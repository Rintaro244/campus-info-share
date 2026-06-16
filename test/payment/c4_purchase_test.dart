/// C4 取引・決済処理部 M2/M3 + 購入フローのユニットテスト。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';
import 'package:student_information_1/payment/m2_purchase_control.dart';
import 'package:student_information_1/payment/m3_gateway_integration.dart';
import 'package:student_information_1/payment/ui/payment_flow_navigation.dart';

class FakeItemRepository implements ItemRepository {
  final int? amount;
  final C4Exception? lockError;
  int unlockCalls = 0;

  FakeItemRepository({this.amount, this.lockError});

  @override
  Future<LockResult> lockItemForPurchase({
    required String listingId,
    required String buyerId,
  }) async {
    final error = lockError;
    if (error != null) {
      throw error;
    }
    return LockResult(status: 'locked', amount: amount ?? 0);
  }

  @override
  Future<String> unlockItem({required String listingId}) async {
    unlockCalls++;
    return 'unlocked';
  }
}

class FakePaymentGateway implements PaymentGatewayClient {
  final C4Exception? intentError;
  FakePaymentGateway({this.intentError});

  @override
  Future<PaymentIntentResult> createPaymentIntent({
    required String listingId,
    required int amount,
    required String buyerUid,
  }) async {
    final error = intentError;
    if (error != null) {
      throw error;
    }
    return const PaymentIntentResult(
      clientSecret: 'cs_test_123',
      paymentIntentId: 'pi_test_123',
    );
  }
}

class FakeNavigator implements PaymentNavigator {
  bool cardEntryShown = false;
  bool backToDetail = false;
  int? lastErrorCode;

  @override
  void goToCardEntry({
    required String clientSecret,
    required String paymentIntentId,
    required int amount,
  }) {
    cardEntryShown = true;
  }

  @override
  void backToItemDetail({required String reason}) {
    backToDetail = true;
  }

  @override
  void showError({required int code, required String message}) {
    lastErrorCode = code;
  }
}

class FakePendingStore implements PendingItemStore {
  @override
  String? pendingItemId;
  FakePendingStore(this.pendingItemId);
}

void main() {
  group('M2 PurchaseControlModule.initiatePurchase', () {
    test('正常系: ロック結果と確定金額を返す', () async {
      final repo = FakeItemRepository(amount: 1500);
      final m2 = PurchaseControlModule(repo);
      final result =
          await m2.initiatePurchase(buyerId: 'buyer1', listingId: 'item1');
      expect(result.status, 'locked');
      expect(result.amount, 1500);
    });

    test('入力欠落: 400 を送出する', () async {
      final m2 = PurchaseControlModule(FakeItemRepository(amount: 0));
      expect(
        () => m2.initiatePurchase(buyerId: '', listingId: 'item1'),
        throwsA(isA<C4Exception>().having((e) => e.code, 'code', 400)),
      );
    });

    test('在庫切れ: C5 の 409 をそのまま伝播する', () async {
      final repo =
          FakeItemRepository(lockError: const C4Exception(409, '在庫切れ'));
      final m2 = PurchaseControlModule(repo);
      expect(
        () => m2.initiatePurchase(buyerId: 'b', listingId: 'i'),
        throwsA(isA<C4Exception>().having((e) => e.code, 'code', 409)),
      );
    });
  });

  group('M3 GatewayIntegrationModule.createPaymentIntent', () {
    test('正常系: clientSecret と paymentIntentId を返す', () async {
      final repo = FakeItemRepository(amount: 1500);
      final m3 = GatewayIntegrationModule(
        paymentGateway: FakePaymentGateway(),
        itemRepository: repo,
      );
      final result = await m3.createPaymentIntent(
        listingId: 'item1',
        amount: 1500,
        buyerId: 'buyer1',
      );
      expect(result.clientSecret, 'cs_test_123');
      expect(result.paymentIntentId, 'pi_test_123');
      expect(repo.unlockCalls, 0);
    });

    test('失敗時: 在庫ロックを解除してから再送出する', () async {
      final repo = FakeItemRepository(amount: 1500);
      final m3 = GatewayIntegrationModule(
        paymentGateway:
            FakePaymentGateway(intentError: const C4Exception(502, 'GW エラー')),
        itemRepository: repo,
      );
      await expectLater(
        () => m3.createPaymentIntent(
          listingId: 'item1',
          amount: 1500,
          buyerId: 'buyer1',
        ),
        throwsA(isA<C4Exception>().having((e) => e.code, 'code', 502)),
      );
      expect(repo.unlockCalls, 1);
    });
  });

  group('PurchaseFlowCoordinator.confirmAndPay（画面遷移）', () {
    test('正常系: 決済画面へ遷移し readyForPayment を返す', () async {
      final repo = FakeItemRepository(amount: 1500);
      final nav = FakeNavigator();
      final coordinator = PurchaseFlowCoordinator(
        m2: PurchaseControlModule(repo),
        m3: GatewayIntegrationModule(
          paymentGateway: FakePaymentGateway(),
          itemRepository: repo,
        ),
        navigator: nav,
        pendingStore: FakePendingStore('item1'),
      );
      final session = await coordinator.confirmAndPay(buyerId: 'buyer1');
      expect(session.stage, PurchaseStage.readyForPayment);
      expect(session.canProceedToPayment, isTrue);
      expect(nav.cardEntryShown, isTrue);
    });

    test('c_pending_item_id 未設定: 中断し W14 へ戻す', () async {
      final repo = FakeItemRepository(amount: 1500);
      final nav = FakeNavigator();
      final coordinator = PurchaseFlowCoordinator(
        m2: PurchaseControlModule(repo),
        m3: GatewayIntegrationModule(
          paymentGateway: FakePaymentGateway(),
          itemRepository: repo,
        ),
        navigator: nav,
        pendingStore: FakePendingStore(null),
      );
      final session = await coordinator.confirmAndPay(buyerId: 'buyer1');
      expect(session.stage, PurchaseStage.aborted);
      expect(nav.backToDetail, isTrue);
    });

    test('在庫切れ: エラー表示し中断する', () async {
      final repo =
          FakeItemRepository(lockError: const C4Exception(409, '在庫切れ'));
      final nav = FakeNavigator();
      final coordinator = PurchaseFlowCoordinator(
        m2: PurchaseControlModule(repo),
        m3: GatewayIntegrationModule(
          paymentGateway: FakePaymentGateway(),
          itemRepository: repo,
        ),
        navigator: nav,
        pendingStore: FakePendingStore('item1'),
      );
      final session = await coordinator.confirmAndPay(buyerId: 'buyer1');
      expect(session.stage, PurchaseStage.aborted);
      expect(nav.lastErrorCode, 409);
    });

    test('完了処理: c_pending_item_id をクリアする', () {
      final store = FakePendingStore('item1');
      final coordinator = PurchaseFlowCoordinator(
        m2: PurchaseControlModule(FakeItemRepository(amount: 0)),
        m3: GatewayIntegrationModule(
          paymentGateway: FakePaymentGateway(),
          itemRepository: FakeItemRepository(amount: 0),
        ),
        navigator: FakeNavigator(),
        pendingStore: store,
      );
      coordinator.onPurchaseCompleted();
      expect(store.pendingItemId, isNull);
    });
  });
}
