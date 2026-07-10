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
}) {
  return ProviderScope(
    overrides: [
      cardPaymentClientProvider.overrideWithValue(client),
      paymentNavigatorProvider.overrideWithValue(navigator),
    ],
    child: const MaterialApp(home: CardEntryScreen(args: _args)),
  );
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
    await tester.pumpWidget(_buildApp(client: client, navigator: nav));

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
  });

  testWidgets('③ 支払う→confirmPayment失敗→showError、遷移せずボタン再活性', (tester) async {
    final client = FakeCardPaymentClient(
      failWith: const C4Exception(402, 'カードが拒否されました。'),
    );
    final nav = RecordingNavigator();
    await tester.pumpWidget(_buildApp(client: client, navigator: nav));

    await tester.tap(find.widgetWithText(FilledButton, '支払う'));
    await tester.pumpAndSettle();

    expect(client.confirmCalls, 1);
    expect(nav.goToCompleteCalls, 0); // 遷移していない
    expect(nav.errorCode, 402);
    expect(nav.errorMessage, 'カードが拒否されました。');

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
}
