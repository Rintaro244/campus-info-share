import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'mainscreen.dart';
import 'payment/payment_integration.dart';

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
      // C4 決済フロー用（担当: 木幡）。名前付きルートは C4 の分のみで、
      // 既存の MaterialPageRoute 遷移（スポット等）には影響しない。
      navigatorKey: paymentNavigatorKey,
      scaffoldMessengerKey: paymentMessengerKey,
      onGenerateRoute: onGeneratePaymentRoute,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}