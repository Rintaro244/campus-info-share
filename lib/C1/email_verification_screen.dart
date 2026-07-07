import 'dart:async';
import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // コントローラーのインスタンスを作成
  final _controller = AuthenticationController();
  
  // タイマーを管理する変数（破棄できるようにここに定義する）
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 1. 画面が表示されたら、3秒ごとに実行するタイマーを開始
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      
      // 2. コントローラー経由でC2➔C5➔Firebaseへ認証が完了したか確認
      final isVerified = await _controller.checkEmailVerified();
      
      if (isVerified) {
        // 3. 認証が完了していたら、まずタイマーを止める（二度と動かないようにする）
        _timer?.cancel();
        
        // 4. 画面がすでに閉じられていないか安全確認（Flutterの決まり文句）
        if (!mounted) return;
        
        // 5. 登録完了画面（またはホーム画面）へ遷移
        Navigator.pushReplacementNamed(context, '/registration-success');
      }
    });
  }

  @override
  void dispose() {
    // 6. 重要：画面が消えるときは必ずタイマーを止める（メモリリーク・裏での通信暴走を防ぐ）
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メールアドレスの確認')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mark_email_unread, size: 80, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                '確認メールを送信しました。\nメール内のリンクをタップして認証を完了させてください。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              
              // 自動チェック中であることをユーザーに示すグルグル
              CircularProgressIndicator(), 
              SizedBox(height: 16),
              Text(
                'メールのリンクがタップされるのを待っています...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}