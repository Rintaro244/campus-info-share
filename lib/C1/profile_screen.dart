import 'package:flutter/material.dart';
import 'profile_edit_screen.dart'; // さっき作った画面をインポート

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 💡 ステップ2：ここに「仮の投稿データ（ダミーデータ）」を用意します
    final List<Map<String, String>> dummyPosts = [
      {'title': '【譲ります】基本情報技術者試験の参考書', 'date': '2026/06/12', 'category': '教材'},
      {'title': 'テニスサークル 今週の練習はお休みです 🎾', 'date': '2026/06/10', 'category': 'サークル'},
      {'title': '【求む】2年の情報数学演習の過去問持ってる人いませんか', 'date': '2026/06/08', 'category': '過去問'},
      {'title': '大宮キャンパス周辺のおすすめラーメン屋まとめ 🍜', 'date': '2026/06/05', 'category': '周辺情報'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'プロフィール',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            '芝浦 太郎',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: OutlinedButton(
              onPressed: (){
              // Navigator.push を使うことで、新しい画面へ進む（遷移する）ことができます！
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileEditScreen(), // さっき作った画面の名前
        ),
      );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'プロフィールを編集',
                style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(thickness: 1, color: Colors.grey[200], height: 1),
          
          // ⑤ 過去の投稿一覧エリア（アップデート！）
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
                          '過去の投稿 (${dummyPosts.length}件)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  
                  // 実際のリストを表示するウィジェット
                  Expanded(
                    child: ListView.builder(
                      itemCount: dummyPosts.length, // リストの件数
                      itemBuilder: (context, index) {
                        final post = dummyPosts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                post['category']!,
                                style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              post['title']!,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis, // 長い文字は「...」にする
                            ),
                            subtitle: Text(
                              post['date']!,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            onTap: () {
  // 💡 投稿がタップされたら、詳細ポップアップ（ダイアログ）を表示する
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // 角丸デザイン
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                post['category']!,
                style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Text('投稿の詳細', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, // 中身のサイズに合わせる
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['title']!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              '投稿日: ${post['date']!}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '※ここに投稿の本文の全体像が詳しく表示されます。設計書に合わせてテキストの量や見た目を調整していきます。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
        actions: [
          // ① 閉じるボタン
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // ダイアログを閉じる
            child: const Text('閉じる', style: TextStyle(color: Colors.grey)),
          ),
          
          // ② 削除ボタン（赤色で強調）
          TextButton(
            onPressed: () {
              // TODO: 後でここにC3モジュールの「削除関数」を呼び出す処理を書く
              print('${post['title']} の削除ボタンが押されました。本来はここでDBから消します。');
              
              Navigator.of(context).pop(); // ダイアログを閉じる
              
              // 削除完了を知らせるスマホ特有のふわっとした通知（スナックバー）
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('「${post['title']}」を削除しました（擬似処理）')),
              );
            },
            child: const Text('削除する', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
},
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => print("ログアウトボタンが押されました"),
        backgroundColor: Colors.red[400],
        elevation: 4,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text('ログアウト', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}