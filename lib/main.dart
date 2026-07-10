import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'mainscreen.dart';
import 'C1/auth/login_screen.dart';
import 'C1/auth/registration_screen.dart';
import 'C1/auth/email_verification_screen.dart';
import 'C1/auth/registration_success_screen.dart';
import 'C1/auth/mfa_setup_screen.dart';
import 'C1/auth/otp_screen.dart';
import 'payment/payment_integration.dart';

// Stripe publishable key（pk_test_...）は公開前提の鍵だが、リポジトリには直書きせず
// 実行時に --dart-define で渡す:
//   flutter run -d chrome --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
// 未指定でもアプリは起動する（決済フローに入ったときだけカード決済が使えない）。
const String _stripePublishableKey =
    String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

// firebase_options.dart は共有Firebase(campus-info-share)用を
// リポジトリ管理し、班全員で同一のものを使用する。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 空キーガード: キー未指定（スポット担当が --dart-define 無しで起動する等）でも
  // クラッシュせず起動する。キーがあるときだけ Stripe を初期化する。
  if (_stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = _stripePublishableKey;
    await Stripe.instance.applySettings();
  }
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学内情報共有アプリ',
      // C4 決済フロー用（担当: 木幡）。名前付きルートは C4 の分のみで、
      // 既存の MaterialPageRoute 遷移（スポット等）には影響しない。
      navigatorKey: paymentNavigatorKey,
      scaffoldMessengerKey: paymentMessengerKey,
      onGenerateRoute: onGeneratePaymentRoute,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      //home: const MainScreen(),
      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegistrationScreen(),
        '/email-verification': (context) => const EmailVerificationScreen(),
        '/registration-success': (context) => const RegistrationSuccessScreen(),
        '/mfa-setup': (context) => const MfaSetupScreen(),
        '/otp': (context) => OtpScreen(),
        '/home': (context) => const MainScreen(),
      },

    );
  }
}