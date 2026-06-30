import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'features/spot/spot_search_screen.dart';

// firebase_options.dart は .gitignore 対象のため、
// `flutterfire configure` を実行して生成し、
// DefaultFirebaseOptions.currentPlatform を options に渡すこと。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学内情報共有システム',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // TODO: 本番はW1起点（ログイン画面）。W1未実装のため当面SpotSearchScreenを直接起動
      home: const SpotSearchScreen(),
    );
  }
}