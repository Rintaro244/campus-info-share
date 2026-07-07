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
                    // 完全ログイン成功（MFA不要な世界線または突破後）
                    Navigator.pushReplacementNamed(context, '/home');
                  } else if (result == 2) {
                    // 登録済みユーザー：OTP入力画面へ
                    Navigator.pushNamed(context, '/otp');
                  } else if (result == 3) {
                    // 初回ユーザー：MFAセットアップ画面へ
                    Navigator.pushNamed(context, '/mfa-setup');
                  }
                } catch (e) {
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