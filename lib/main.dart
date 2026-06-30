import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mainscreen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

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