import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = AuthenticationController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: _isPasswordObscure,
              decoration: InputDecoration(
                labelText: 'パスワード',
                // 👇 IconButtonの代わりにGestureDetectorを使う
                suffixIcon: GestureDetector(
                  // ① ボタンを「押し込んだ」瞬間にパスワードを表示
                  onTapDown: (_) {
                    setState(() {
                      _isPasswordObscure = false;
                    });
                  },
                  // ② ボタンから「指を離した」瞬間にパスワードを隠す
                  onTapUp: (_) {
                    setState(() {
                      _isPasswordObscure = true;
                    });
                  },
                  // ③ ボタンを押したまま指を画面外に「ずらして離した」時も隠す（安全対策）
                  onTapCancel: () {
                    setState(() {
                      _isPasswordObscure = true;
                    });
                  },
                  // アイコン
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      _isPasswordObscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final result = await _controller.submitLogin(
                    _emailController.text,
                    _passwordController.text,
                  );

                  if (!context.mounted) return;

                  if (result == 1) {
                    // 完全ログイン成功。/login をスタックから消してホームへ
                    // （戻る矢印でログイン画面に戻れてしまう問題を防ぐ）
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (route) => false);
                  } else if (result == 2) {
                    // 登録済みユーザー：OTP入力画面へ
                    Navigator.pushNamed(context, '/otp');
                  } else if (result == 3) {
                    // 初回ユーザー：MFAセットアップ画面へ
                    Navigator.pushNamed(context, '/mfa-setup');
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  //エラー表示が順番待ちにならないように前のものを消す
                  ScaffoldMessenger.of(context).clearSnackBars();
                  if(e.toString().contains('EmailNotVerifiedException') || e.toString().contains('メール認証')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('メール認証が完了していません。確認画面へ移動します')),
                    );

                    try {
                      await _controller.resendEmail();
                    } catch (_) {
                      //アプリ落ち対策
                    }
                    if (!context.mounted) return;
                    // 認証画面へ飛ばす！（戻るボタンでログイン画面に戻れるよう pushNamed がおすすめ）
                    Navigator.pushNamed(context, '/email-verification');
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: const Text('ログイン'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('アカウント新規作成はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}