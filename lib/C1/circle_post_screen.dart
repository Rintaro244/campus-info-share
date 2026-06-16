import 'package:flutter/material.dart';

// W8 サークル投稿画面
class CirclePostScreen extends StatefulWidget {
  const CirclePostScreen({Key? key}) : super(key: key);

  @override
  State<CirclePostScreen> createState() => _CirclePostScreenState();
}

class _CirclePostScreenState extends State<CirclePostScreen> {
  // 💡 追加: テストロボットがスナックバーを100%見つけられるようにするための魔法のキー
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedCampus = '豊洲';
  String _selectedCategory = '運動系';

  bool _isImageSelected = false;
  bool _simulateLargeFile = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submitPost() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    // ① 必須項目未入力エラー
    if (name.isEmpty || desc.isEmpty) {
      // 💡 修正: context ではなく _messengerKey を使って確実にスナックバーを出します
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('必須項目が入力されていません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ② ファイルサイズエラー
    if (_isImageSelected && _simulateLargeFile) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('ファイルサイズが大きすぎます。1MB以下のファイルを選択してください。'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ③ 登録完了（仮）
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('「$name」を登録しました（擬似処理）'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 💡 修正: 画面の一番外側を ScaffoldMessenger で包み、上記のキーをセットします
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('サークル・部活動登録', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('団体名 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: '例: 芝浦ベースボールクラブ',
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[600]!, width: 2), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('活動キャンパス *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCampus,
                items: ['豊洲', '大宮', '両方'].map((campus) {
                  return DropdownMenuItem(value: campus, child: Text(campus));
                }).toList(),
                onChanged: (value) => setState(() { _selectedCampus = value!; }),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),

              const Text('カテゴリ *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: ['運動系', '文化系', 'その他'].map((category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }).toList(),
                onChanged: (value) => setState(() { _selectedCategory = value!; }),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),

              const Text('紹介文 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLength: 800,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'サークルの活動内容、頻度、新歓情報などを入力してください。',
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[600]!, width: 2), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('カバー画像', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() { _isImageSelected = !_isImageSelected; });
                },
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isImageSelected ? Colors.blue[300]! : Colors.grey[300]!, width: 1),
                  ),
                  child: _isImageSelected
                      ? const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('画像が選択されています（タップで解除）', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, color: Colors.grey, size: 32),
                              SizedBox(height: 4),
                              Text('画像をアップロード (タップして選択)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                ),
              ),
              
              if (_isImageSelected) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('テスト用: 選択した画像を1MB超えにする', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Switch(
                      value: _simulateLargeFile,
                      onChanged: (val) {
                        setState(() { _simulateLargeFile = val; });
                      },
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text(
                  'この内容で登録する',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}