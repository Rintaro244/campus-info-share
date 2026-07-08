/// 学内情報共有システム — C4 取引・決済処理部
/// 開発用エントリポイント（Firebase エミュレータ接続 + W13 直起動）
///
/// 本番 DB を汚さずに決済フロー（W13→W14→W15→確定）を手元で通すための起動口。
/// 使い方:
///   1. エミュレータ起動（auth:19099 / firestore:18080 / functions:15001）
///   2. Admin SDK 等で items に on_sale の教材をシード
///   3. flutter run -d chrome -t lib/payment/dev_emulator_main.dart
/// 通常ビルド（lib/main.dart）には一切影響しない。
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/firebase_options.dart';
import 'package:student_information_1/payment/payment_integration.dart';
import 'package:student_information_1/payment/services/callable_error_mapper.dart';
import 'package:student_information_1/payment/ui/screens/item_list_screen.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // 開発確認用: セマンティクスツリーを常時有効化する
  // （ヘッドレスブラウザや支援技術から要素を特定できるようにする）。
  binding.ensureSemantics();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // すべてローカルエミュレータへ向ける（本番へは一切通信しない）。
  await FirebaseAuth.instance.useAuthEmulator('localhost', 19099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 18080);
  FirebaseFunctions.instanceFor(region: functionsRegion)
      .useFunctionsEmulator('localhost', 15001);

  // エミュレータ限定: 匿名ログインで request.auth.uid を確保する。
  await FirebaseAuth.instance.signInAnonymously();

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
      home: const ItemListScreen(),
    );
  }
}
