import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class OtpScreen extends StatelessWidget {
  final _controller = AuthenticationController();
  final _otpController = TextEditingController();

  OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP認証')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Microsoft Authenticatorで表示された6桁のワンタイムパスワードコードを入力してください'),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: '認証コード'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try{
                  await _controller.submitOtp(_otpController.text);
                  if (!context.mounted) return;
                  // 認証成功でホーム画面へ。/login をスタックから消す
                  // （戻る矢印でログイン画面に戻れてしまう問題を防ぐ）
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (route) => false);
                } catch (e) {
                  if (!context.mounted) return;
                  //エラー表示が順番待ちにならないように前のものを消す
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),);
                }
              },
              child: const Text('認証してログイン'),
            ),
          ],
        ),
      ),
    );
  }
}