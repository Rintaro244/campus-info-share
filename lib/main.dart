import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'mainscreen.dart';

void main() async{
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


class MyApp extends StatelessWidget{
  const MyApp({super.key});
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: '学内情報共有アプリ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(), //first show
    );
  }
}


/*
Login画面と結合したら，ログイン完了後に遷移する画面(最初に呼び出すクラス)
をMainScreen()に変更すればok

MainScreen()のfinal List<Widget>にそれぞれの一番最初に開きたいメインページに
変更して，各.dartファイルをimport

*/