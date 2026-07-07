import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class RegistrationScreen extends StatelessWidget {
  final _controller = AuthenticationController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント新規作成')),
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
            TextField(
              controller: _passwordConfirmController,
              decoration: const InputDecoration(labelText: '確認用パスワード'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _controller.submitRegistration(
                    _emailController.text,
                    _passwordController.text,
                    _passwordConfirmController.text,
                  );
                  if (!context.mounted) return;
                  
                  // 登録処理が成功したらメール確認画面へ（現在の画面は破棄）
                  Navigator.pushReplacementNamed(context, '/email-verification');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('アカウント作成'),
            ),
          ],
        ),
      ),
    );
  }
}