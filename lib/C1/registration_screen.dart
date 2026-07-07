import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _controller = AuthenticationController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isPasswordObscure = true;
  bool _isConfiremPasswordObscure = true;

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
            TextField(
              controller: _passwordConfirmController,
              obscureText: _isConfiremPasswordObscure,
              decoration: InputDecoration(
                labelText: 'パスワード',
                // 👇 IconButtonの代わりにGestureDetectorを使う
                suffixIcon: GestureDetector(
                  // ① ボタンを「押し込んだ」瞬間にパスワードを表示
                  onTapDown: (_) {
                    setState(() {
                      _isConfiremPasswordObscure = false;
                    });
                  },
                  // ② ボタンから「指を離した」瞬間にパスワードを隠す
                  onTapUp: (_) {
                    setState(() {
                      _isConfiremPasswordObscure = true;
                    });
                  },
                  // ③ ボタンを押したまま指を画面外に「ずらして離した」時も隠す（安全対策）
                  onTapCancel: () {
                    setState(() {
                      _isConfiremPasswordObscure = true;
                    });
                  },
                  // アイコン
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      _isConfiremPasswordObscure ? Icons.visibility_off : Icons.visibility,
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
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
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