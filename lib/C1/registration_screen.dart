import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class RegistrationScreen extends StatelessWidget {
  final _controller = AuthenticationController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('アカウント新規作成')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'メールアドレス'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            TextField(
              controller: _passwordConfirmController,
              decoration: InputDecoration(labelText: '確認用パスワード'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final isValid = await _controller.submitRegistration(
                    _emailController.text,
                    _passwordController.text,
                    _passwordConfirmController.text,
                  );

                  if (isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('確認メールを送信しました。')),
                    );
                    Navigator.pop(context); // ログイン画面に戻る
                  }
                } catch (e) {
                  // E1やE2のエラーメッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: Text('アカウント作成'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ログインはこちら'),
            ),
          ],
        ),
      ),
    );
  }
}