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
  int _tickCount = 0;
  final int _maxTicks = 100; //3秒ごとのTickが100回呼び出されたらタイムアウト

  Timer? _resendTimer;
  int _resendCountdown = 0; // 0のときはボタンを押せる
  bool _isResending = false;

  @override
  void initState() {
    super.initState();

    _resendCountdown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel(); // 0になったらタイマー停止
        }
      });
    });

    // 画面が表示されたらタイマー開始
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      ++_tickCount;

      if (_tickCount >= _maxTicks) { 
        _timer?.cancel();

        try{
          await _controller.deleteCurrentTemporaryAccount();
        } catch (e) {
          debugPrint(e.toString());
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('メール確認の期限が切れました。最初からやり直してください')));
        Navigator.pushReplacementNamed(context, '/register');
        return;
      }
      
      try {
        // コントローラー経由でC2➔C5➔Firebaseへ認証が完了したか確認
        final isVerified = await _controller.checkEmailVerified();
        
        if (isVerified) {
          // 認証が完了していたら、まずタイマーを止める
          _timer?.cancel();
          
          if (!mounted) return;
          
          // 登録完了画面へ遷移
          Navigator.pushReplacementNamed(context, '/registration-success');
        }
      } catch (e) {
        _timer?.cancel();

        // 裏で残っているかもしれないアカウント情報をクリーンアップ
        try { await _controller.deleteCurrentTemporaryAccount(); } catch (_) {}
        
        if (!mounted) return;
        // エラーメッセージを表示して、新規登録画面に戻す
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')))
        );
        Navigator.pushReplacementNamed(context, '/register');
      }
    });
  }

  // メール再送ボタンが押された時の処理
  Future<void> _handleResendEmail() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _controller.resendEmail(); 
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('確認メールを再送信しました')),
      );

      // 再送タイマーを開始
      setState(() {
        _resendCountdown = 60;
        _isResending = false;
      });

      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCountdown == 0) {
          timer.cancel();
        } else {
          setState(() {
            _resendCountdown--;
          });
        }
      });
    } catch (e) {
      setState(() { _isResending = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再送信に失敗しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
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
            children:[
              const Icon(Icons.mark_email_unread, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                '確認メールを送信しました。\nメール内のリンクをタップして認証を完了させてください。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // 自動チェック中であることをユーザーに示すグルグル
              const CircularProgressIndicator(), 
              const SizedBox(height: 16),
              const Text(
                'メールのリンクがタップされるのを待っています...',
                style: TextStyle(color: Colors.grey),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _resendCountdown > 0 ? null : _handleResendEmail,
                child: Text(
                  _resendCountdown > 0 
                      ? '再送信まであと $_resendCountdown 秒' 
                      : '確認メールを再送信する',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}