import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 👈 QRコード描画パッケージ
import 'authentication_controller.dart';

class MfaSetupScreen extends StatefulWidget {
  const MfaSetupScreen({super.key});

  @override
  State<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends State<MfaSetupScreen> {
  final _controller = AuthenticationController();
  final _otpController = TextEditingController();

  // 画面の状態を管理する変数
  String? _qrCodeUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQrCode(); // 画面が開かれた瞬間にURLを取得しにいく
  }

  Future<void> _loadQrCode() async {
    try {
      // ⚠️注意: AuthenticationController側に initiateMfaSetup() という
      // URL(String)を返すメソッドが実装されている前提のコードです。
      final url = await _controller.startMfaSetup();
      
      if (mounted) {
        setState(() {
          _qrCodeUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MFA初期設定 (初回のみ)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Microsoft AuthenticatorアプリからQRコードを読み取り、表示された6桁のワンタイムパスワードコードを入力してください。'),
            const SizedBox(height: 16),
            
            // 👇 状態によって表示を切り替えるロジック
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text('エラー: $_errorMessage', style: const TextStyle(color: Colors.red))
            else if (_qrCodeUrl != null)
              QrImageView(
                data: _qrCodeUrl!,       // 取得したURLデータを渡す
                version: QrVersions.auto, // 自動で最適な密度に設定
                size: 200.0,
              ),

            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: '6桁の認証コード'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                // 👇 万が一OTPが間違っていた時のために try-catch を追加しています
                try {
                  await _controller.completeMfaEnrollment(_otpController.text);
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/home');
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: const Text('設定を完了して次へ'),
            ),
          ],
        ),
      ),
    );
  }
}