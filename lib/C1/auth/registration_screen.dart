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
  bool _isConfirmPasswordObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規アカウント作成')),
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
              obscureText: _isConfirmPasswordObscure,
              decoration: InputDecoration(
                labelText: '確認用パスワード',
                // 👇 IconButtonの代わりにGestureDetectorを使う
                suffixIcon: GestureDetector(
                  // ① ボタンを「押し込んだ」瞬間にパスワードを表示
                  onTapDown: (_) {
                    setState(() {
                      _isConfirmPasswordObscure = false;
                    });
                  },
                  // ② ボタンから「指を離した」瞬間にパスワードを隠す
                  onTapUp: (_) {
                    setState(() {
                      _isConfirmPasswordObscure = true;
                    });
                  },
                  // ③ ボタンを押したまま指を画面外に「ずらして離した」時も隠す（安全対策）
                  onTapCancel: () {
                    setState(() {
                      _isConfirmPasswordObscure = true;
                    });
                  },
                  // アイコン
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      _isConfirmPasswordObscure ? Icons.visibility_off : Icons.visibility,
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
                  if (!context.mounted) return;
                  //エラー表示が順番待ちにならないように前のものを消す
                  ScaffoldMessenger.of(context).clearSnackBars();
                  //メアドが既に使用されていてかつ未認証
                  if(e.toString().contains('EmailNotVerifiedException')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('登録途中のアカウントが見つかりました。認証画面へ移動します。')),
                    );
                    Navigator.pushReplacementNamed(context, '/email-verification');
                    return;
                  }


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