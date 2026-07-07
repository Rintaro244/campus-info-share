import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 💡 ご自身のプロジェクトの実際のファイル名（スネークケースなど）に合わせて適宜修正してください
import 'mainscreen.dart'; 
import 'past_exam_screen.dart'; 

void main() async {
  // Flutterの初期化処理を確実に行うための決まり文句
  WidgetsFlutterBinding.ensureInitialized();
  
  // 💡 Firebaseの初期設定を有効化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // Riverpodをアプリ全体で有効にするためのスコープ
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
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      
      home: const PastExamListScreen(), 
    );
  }
}
/*
Login画面と結合したら，ログイン完了後に遷移する画面(最初に呼び出すクラス)
をMainScreen()に変更すればok

MainScreen()のfinal List<Widget>にそれぞれの一番最初に開きたいメインページに
変更して，各.dartファイルをimport
*/