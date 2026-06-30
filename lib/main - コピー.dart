import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

// 💡 同じフォルダにある過去問一覧画面をインポート
import 'past_exam_screen.dart'; 

void main() async {
  // FlutterのシステムとFirebaseを安全に繋ぐための呪文
  WidgetsFlutterBinding.ensureInitialized();
  
  /*
  try {
    //すでにプロジェクト側でFirebaseの設定ファイル（firebase_options.dart）などが
    // 導入されている場合は、これでFirebaseが初期化
    await Firebase.initializeApp();
  } catch (e) {
    // もしFirebaseの初期化設定（flutterfire configureなど）がまだ終わっていなくても、
    print("Firebase初期化未完了(テスト実行を継続します): $e");
  }
  */

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学内情報共有アプリ テスト',
      debugShowCheckedModeBanner: false, // 画面右上の「DEBUG」リボンを非表示にする
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // モダンなデザインを適用
      ),
      // 💡 アプリを起動した瞬間に、いきなり「過去問一覧画面」が開くように設定！
      home: const PastExamListScreen(),
    );
  }
}