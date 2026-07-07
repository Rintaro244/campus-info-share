import 'package:flutter/material.dart';
import 'profile_validator.dart';
import '../C3/user_manager.dart'; // 💡 追加（パスは適宜調整してください）

class ProfileEditScreen extends StatefulWidget {
  final String currentName; // 💡 追加：前の画面から現在の名前を受け取る

  const ProfileEditScreen({Key? key, required this.currentName}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  bool _isSaving = false; // 💡 保存中のくるくる表示用

  @override
  void initState() {
    super.initState();
    // 💡 画面が開かれたときに、現在の名前を最初から入力しておく
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<bool> _showBackConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('変更の破棄'),
        content: const Text('編集内容を保存せずに戻りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('編集を続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('破棄して戻る', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_nameController.text != widget.currentName) {
          return await _showBackConfirmDialog();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('プロフィール編集', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () async {
              if (_nameController.text != widget.currentName) {
                final shouldPop = await _showBackConfirmDialog();
                if (shouldPop && context.mounted) Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ユーザー名', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '例: 芝浦 太郎',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 48),
              
              _isSaving 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () async {
                      final text = _nameController.text.trim();
                      
                      if (!ProfileValidator.validateUserName(text)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ユーザ名を正しく入力してください。(例:1文字以上20文字以内等)'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setState(() { _isSaving = true; });

                      // 💡 Firestoreに新しい名前を保存する！
                      final success = await UserManager().updateUserName('dummy_user_123', text);
                      
                      setState(() { _isSaving = false; });

                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィールを保存しました')));
                        Navigator.of(context).pop(true); // 💡 保存成功を前の画面に伝えるために true を返す
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存に失敗しました'), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('変更を保存する', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}