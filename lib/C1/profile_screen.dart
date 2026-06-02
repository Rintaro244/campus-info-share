import 'package:flutter/material.dart';

// プロフィール画面のクラス
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('プロフィール')),
      body: Center(child: Text('ここにプロフィールが表示されます')),
    );
  }
}
