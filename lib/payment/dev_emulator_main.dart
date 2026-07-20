/// 学内情報共有システム — C4 取引・決済処理部
/// 開発用エントリポイント（Firebase エミュレータ接続 + 教材一覧 直起動）
///
/// 本番 DB を汚さずに決済フロー（一覧→詳細→支払方法選択→確定）を手元で通すための起動口。
/// 使い方:
///   1. エミュレータ起動（auth:9099 / firestore:8080 / functions:5001）
///   2. Admin SDK 等で items に on_sale の教材をシード
///   3. flutter run -d chrome -t lib/payment/dev_emulator_main.dart \
///        --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
///      （カード決済まで通す場合はキー必須。未指定だと CardEntryScreen で
///        StripeConfigException になる）
/// 通常ビルド（lib/main.dart）には一切影響しない。
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:student_information_1/C1/market_search_screen.dart';
import 'package:student_information_1/firebase_options.dart';
import 'package:student_information_1/payment/payment_integration.dart';
import 'package:student_information_1/payment/services/callable_error_mapper.dart';

// Stripe publishable key（pk_test_...）。lib/main.dart と同じく実行時に渡す:
//   --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
// 値は接頭辞込みの完全な文字列を渡すこと（pk_test_ を二重に付けない）。
const String _stripePublishableKey =
    String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // すべてローカルエミュレータへ向ける（本番へは一切通信しない）。
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instanceFor(region: functionsRegion)
      .useFunctionsEmulator('localhost', 5001);

  // エミュレータ限定: 匿名ログインで request.auth.uid を確保する。
  await FirebaseAuth.instance.signInAnonymously();

  // Stripe 初期化（lib/main.dart と同じ空キーガード付き）。
  // これが無いと --dart-define を渡しても publishableKey が未設定のままになり、
  // CardEntryScreen の「支払う」で StripeConfigException になる。
  // Stripe は決済ゲートウェイのみを指し、エミュレータには向けない（本物の test 環境へ出る）。
  if (_stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = _stripePublishableKey;
    await Stripe.instance.applySettings();
  } else {
    debugPrint(
      'Stripe 未初期化: STRIPE_PUBLISHABLE_KEY 未指定のため、カード決済は使用できません。',
    );
  }

  runApp(
    const ProviderScope(
      child: PaymentDevApp(),
    ),
  );
}

class PaymentDevApp extends StatelessWidget {
  const PaymentDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C4 決済フロー 開発確認',
      navigatorKey: paymentNavigatorKey,
      scaffoldMessengerKey: paymentMessengerKey,
      onGenerateRoute: onGeneratePaymentRoute,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MarketSearchScreen(),
    );
  }
}
