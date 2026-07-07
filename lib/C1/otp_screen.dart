import 'package:flutter/material.dart';
import 'authentication_controller.dart';

class OtpScreen extends StatelessWidget {
  final _controller = AuthenticationController();
  final _otpController = TextEditingController();

  OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2段階認証')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('認証アプリに表示されている6桁のコード(数字)を入力してください。'),
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
                  // 認証成功でホーム画面へ
                  Navigator.pushReplacementNamed(context, '/home');
                } catch (e) {
                  if (!context.mounted) return;
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