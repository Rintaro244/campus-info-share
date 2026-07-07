// lib/main_auth_test.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

// あなたの作成した画面をインポート
import 'C1/login_screen.dart';
import 'C1/mfa_setup_screen.dart';
import 'C1/otp_screen.dart';
import 'C1/registration_screen.dart';
import 'C1/email_verification_screen.dart';
import 'C1/registration_success_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebaseを使っている場合は初期化が必要
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AuthTestApp());
}

class AuthTestApp extends StatelessWidget {
  const AuthTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '認証UIテスト',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegistrationScreen(),
        '/otp': (context) => OtpScreen(),
        '/mfa-setup': (context) => MfaSetupScreen(),
        '/email-verification': (context) => const EmailVerificationScreen(),
        '/registration-success': (context) => const RegistrationSuccessScreen(),

        
        // ★ 遷移テスト用のダミーホーム画面
        '/home': (context) => Scaffold(
          appBar: AppBar(title: const Text('仮のホーム')),
          body: const Center(child: Text('ログイン成功して遷移しました！')),
        ),
      },
    );
  }
}