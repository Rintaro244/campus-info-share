import 'package:flutter/material.dart';

// W3 プロフィール画面（戻るボタン ＆ ログアウトボタン追加版）
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'プロフィール',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // ヘッダーの影をなくしてフラットに
        centerTitle: true,
        
        // ① 戻るボタン（直前の画面に遷移するボタン）
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () {
            // Navigator.pop で、一つ前の画面に戻る命令になります
            // 今はまだ前の画面がない（最初の画面にしている）ので動きませんが、これで仕組みはバッチリです
            Navigator.of(context).pop();
            print("戻るボタンが押されました");
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          
          // ② ユーザーアイコン（丸型）
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // ③ ユーザー名のみ
          const Text(
            '芝浦 太郎',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // ④ プロフィール編集ボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: OutlinedButton(
              onPressed: () {
                print("プロフィール編集ボタンが押されました");
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'プロフィールを編集',
                style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Divider(thickness: 1, color: Colors.grey[200], height: 1),
          
          // ⑤ 過去の投稿一覧の土台エリア
          Expanded(
            child: Container(
              color: Colors.grey[50],
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '過去の投稿',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '（ここに過去の投稿一覧が表示される予定です）',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ⑥ 右下のログアウトボタン
      // FloatingActionButtonを使うことで、画面のスクロール等に影響されず、スマホの右下に固定されます
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print("ログアウトボタンが押されました");
        },
        backgroundColor: Colors.red[400], // ログアウトなので警告色の赤っぽく
        elevation: 4, // ボタンの影
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'ログアウト',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}