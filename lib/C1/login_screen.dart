import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class LoginScreen extends StatelessWidget {
  final _controller = AuthenticationController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ログイン')),
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
            ElevatedButton(
              onPressed: () async {
                try {
                  final result = await _controller.submitLogin(
                    _emailController.text,
                    _passwordController.text,
                  );

                  if (result == 1) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else if (result == 2) {
                    Navigator.pushNamed(context, '/otp');
                  }
                } catch (e) {
                  // E4やE1のエラーメッセージを画面に表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: Text('ログイン'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text('アカウント新規作成はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}