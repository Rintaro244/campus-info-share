/// C4 決済カード入力画面（card_entry_screen）の widget テスト。
/// Stripe SDK を CardPaymentClient の Fake に差し替え、決済実行〜遷移/エラーを検証する。
/// 実 flutter_stripe には一切触れない（SDK 非依存でテストできる設計の確認も兼ねる）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/providers.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';
import 'package:student_information_1/payment/services/card_payment_client.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';
import 'package:student_information_1/payment/ui/payment_flow_navigation.dart';
import 'package:student_information_1/payment/ui/screens/card_entry_screen.dart';

/// Stripe を模した Fake。成功/失敗（C4Exception）と、処理中を再現する gate を制御できる。
class FakeCardPaymentClient implements CardPaymentClient {
  int confirmCalls = 0;
  final C4Exception? failWith;
  final Completer<void>? gate; // 非 null なら confirmPayment はこれの完了を待つ（処理中再現）。

  FakeCardPaymentClient({this.failWith, this.gate});

  @override
  Widget buildCardInput() => const SizedBox(key: Key('fake-card-input'));

  @override
  Future<void> confirmPayment({required String clientSecret}) async {
    confirmCalls++;
    final g = gate;
    if (g != null) await g.future;
    final e = failWith;
    if (e != null) throw e;
  }
}

/// 在庫ロック解放の記録用 Fake。決済失敗時に unlockItem が呼ばれるか検証する。
class FakeItemRepository implements ItemRepository {
  int unlockCalls = 0;

  @override
  Future<LockResult> lockItemForPurchase({
    required String listingId,
    required String buyerId,
  }) {
    // カード入力画面ではロックは上流(M2)で完了済みのため呼ばれない。
    throw UnimplementedError();
  }

  @override
  Future<String> unlockItem({required String listingId}) async {
    unlockCalls++;
    return 'unlocked';
  }
}

/// PaymentNavigator の記録用 Fake。遷移・エラーの呼び出しを記録する。
class RecordingNavigator implements PaymentNavigator {
  int goToCompleteCalls = 0;
  String? completeListingId;
  String? completeTransactionId;
  int? errorCode;
  String? errorMessage;

  @override
  void goToPurchaseComplete({required String listingId, String? transactionId}) {
    goToCompleteCalls++;
    completeListingId = listingId;
    completeTransactionId = transactionId;
  }

  @override
  void showError({required int code, required String message}) {
    errorCode = code;
    errorMessage = message;
  }

  @override
  void goToCardEntry({
    required String clientSecret,
    required String paymentIntentId,
    required int amount,
    required String listingId,
  }) {}

  @override
  void backToItemDetail({required String reason}) {}
}

const _args = CardEntryArgs(
  clientSecret: 'cs_test_123',
  paymentIntentId: 'pi_test_123',
  amount: 1500,
  listingId: 'item_1',
);

Widget _buildApp({
  required CardPaymentClient client,
  required PaymentNavigator navigator,
  ItemRepository? itemRepository,
}) {
  return ProviderScope(
    overrides: [
      cardPaymentClientProvider.overrideWithValue(client),
      paymentNavigatorProvider.overrideWithValue(navigator),
      // 既定の FirestoreItemRepository は Firebase 初期化を要するため必ず Fake に差し替える。
      itemRepositoryProvider.overrideWithValue(
        itemRepository ?? FakeItemRepository(),
      ),
    ],
    child: const MaterialApp(home: CardEntryScreen(args: _args)),
  );
}

/// 離脱（pop）を伴うテスト用。前画面から push して CardEntryScreen を開く構成にする。
/// `home:` 直置きだと戻るボタンが無く pageBack できないため、こちらを使う。
Widget _buildAppWithPush({
  required CardPaymentClient client,
  required PaymentNavigator navigator,
  ItemRepository? itemRepository,
}) {
  return ProviderScope(
    overrides: [
      cardPaymentClientProvider.overrideWithValue(client),
      paymentNavigatorProvider.overrideWithValue(navigator),
      itemRepositoryProvider.overrideWithValue(
        itemRepository ?? FakeItemRepository(),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CardEntryScreen(args: _args),
              ),
            ),
            child: const Text('カード入力へ'),
          ),
        ),
      ),
    ),
  );
}

/// 前画面から CardEntryScreen へ遷移する。
Future<void> _pushCardEntry(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'カード入力へ'));
  await tester.pumpAndSettle();
  expect(find.text('お支払い金額: ¥1500'), findsOneWidget);
}

void main() {
  testWidgets('① 金額・カード入力欄・支払うボタンを表示する', (tester) async {
    await tester.pumpWidget(
      _buildApp(client: FakeCardPaymentClient(), navigator: RecordingNavigator()),
    );
    await tester.pumpAndSettle();

    expect(find.text('お支払い金額: ¥1500'), findsOneWidget);
    expect(find.byKey(const Key('fake-card-input')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '支払う'), findsOneWidget);
  });

  testWidgets('② 支払う→confirmPayment成功→goToPurchaseComplete(listingId, paymentIntentId)',
      (tester) async {
    final client = FakeCardPaymentClient();
    final nav = RecordingNavigator();
    final repo = FakeItemRepository();
    await tester.pumpWidget(
      _buildApp(client: client, navigator: nav, itemRepository: repo),
    );

    await tester.tap(find.widgetWithText(FilledButton, '支払う'));
    // 成功パスは _processing=true のまま遷移する（実アプリでは新画面へ push される）。
    // 記録用ナビゲータは画面を遷移させずスピナーが回り続けるため、pumpAndSettle ではなく
    // 有限 pump で confirmPayment（microtask）の解決と継続処理をフラッシュする。
    await tester.pump();
    await tester.pump();

    expect(client.confirmCalls, 1);
    expect(nav.goToCompleteCalls, 1);
    expect(nav.completeListingId, 'item_1');
    // 有償フローの transactionId は paymentIntentId（webhook が transactions/{pi} を作る）。
    expect(nav.completeTransactionId, 'pi_test_123');
    expect(nav.errorCode, isNull);
    // 成功時はロックを解放しない（sold 化は Webhook が行う）。
    expect(repo.unlockCalls, 0);
  });

  testWidgets('③ 支払う→confirmPayment失敗→showError、遷移せずボタン再活性', (tester) async {
    final client = FakeCardPaymentClient(
      failWith: const C4Exception(402, 'カードが拒否されました。'),
    );
    final nav = RecordingNavigator();
    final repo = FakeItemRepository();
    await tester.pumpWidget(
      _buildApp(client: client, navigator: nav, itemRepository: repo),
    );

    await tester.tap(find.widgetWithText(FilledButton, '支払う'));
    await tester.pumpAndSettle();

    expect(client.confirmCalls, 1);
    expect(nav.goToCompleteCalls, 0); // 遷移していない
    expect(nav.errorCode, 402);
    expect(nav.errorMessage, 'カードが拒否されました。');
    // 決済失敗時は在庫ロックを解放して on_sale に戻す（再購入可能にする）。
    expect(repo.unlockCalls, 1);

    // 失敗後はボタンが再活性（同じ画面で再試行できる）。
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '支払う'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('④ 処理中の二重タップは confirmPayment を1回しか呼ばない', (tester) async {
    final gate = Completer<void>();
    final client = FakeCardPaymentClient(gate: gate);
    final nav = RecordingNavigator();
    await tester.pumpWidget(_buildApp(client: client, navigator: nav));

    // 1回目タップ → confirmPayment 開始（gate 待ちで処理中に留まる）。
    await tester.tap(find.widgetWithText(FilledButton, '支払う'));
    await tester.pump();
    expect(client.confirmCalls, 1);

    // 処理中はボタンの子がスピナーになりテキスト「支払う」では探せない（＝処理中表示の確認も兼ねる）。
    // ボタン自体は disabled。byType で狙って2回目タップしても発火しない。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(client.confirmCalls, 1); // 増えていない＝二重送信防止

    // gate を解放して完了させる。成功パスはスピナーが回り続けるため有限 pump を使う。
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(client.confirmCalls, 1);
    expect(nav.goToCompleteCalls, 1);
  });

  testWidgets('⑤ 決済せず戻るボタンで離脱すると在庫ロックを解放する', (tester) async {
    final repo = FakeItemRepository();
    await tester.pumpWidget(
      _buildAppWithPush(
        client: FakeCardPaymentClient(),
        navigator: RecordingNavigator(),
        itemRepository: repo,
      ),
    );
    await _pushCardEntry(tester);
    expect(repo.unlockCalls, 0); // 表示しただけでは解放しない

    await tester.pageBack(); // AppBar の戻るボタン
    await tester.pumpAndSettle();

    // 決済を試みずに離脱 → pending を on_sale へ戻す。
    expect(repo.unlockCalls, 1);
  });

  testWidgets('⑥ 決済成功後に画面を破棄してもロックを解放しない（sold 化は Webhook）',
      (tester) async {
    final client = FakeCardPaymentClient();
    final nav = RecordingNavigator();
    final repo = FakeItemRepository();
    await tester.pumpWidget(
      _buildAppWithPush(client: client, navigator: nav, itemRepository: repo),
    );
    await _pushCardEntry(tester);

    await tester.tap(find.widgetWithText(FilledButton, '支払う'));
    // 成功パスは遷移せずスピナーが回り続けるため有限 pump で継続処理をフラッシュする。
    await tester.pump();
    await tester.pump();
    expect(nav.goToCompleteCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // オーソリ成立済み。ここで解放すると成立済みの購入を on_sale へ戻してしまう。
    expect(repo.unlockCalls, 0);
  });

  testWidgets('⑦ 決済失敗後に離脱してもロック解放は1回だけ（二重解放しない）', (tester) async {
    final client = FakeCardPaymentClient(
      failWith: const C4Exception(402, 'カードが拒否されました。'),
    );
    final repo = FakeItemRepository();
    await tester.pumpWidget(
      _buildAppWithPush(
        client: client,
        navigator: RecordingNavigator(),
        itemRepository: repo,
      ),
    );
    await _pushCardEntry(tester);

    await tester.tap(find.widgetWithText(FilledButton, '支払う'));
    await tester.pumpAndSettle();
    expect(repo.unlockCalls, 1); // 失敗時の解放

    await tester.pageBack();
    await tester.pumpAndSettle();

    // dispose 側は解放済みフラグを見て何もしない。
    expect(repo.unlockCalls, 1);
  });
}
