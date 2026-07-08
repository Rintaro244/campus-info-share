import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'mainscreen.dart';
import 'C1/auth/login_screen.dart';
import 'C1/auth/registration_screen.dart';
import 'C1/auth/email_verification_screen.dart';
import 'C1/auth/registration_success_screen.dart';
import 'C1/auth/mfa_setup_screen.dart';
import 'C1/auth/otp_screen.dart';

// firebase_options.dart は共有Firebase(campus-info-share)用を
// リポジトリ管理し、班全員で同一のものを使用する。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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