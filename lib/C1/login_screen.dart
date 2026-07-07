import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class LoginScreen extends StatelessWidget {
  final _controller = AuthenticationController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
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