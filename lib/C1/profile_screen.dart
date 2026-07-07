import 'package:flutter/material.dart';
import 'package:student_information_1/C3/user_manager.dart';
import 'package:student_information_1/past/past_exam_repository.dart';
import 'profile_edit_screen.dart'; 
// 💡 先ほど作ったマネージャーをインポート（パスは環境に合わせて調整してください）
import '../C3/circle_manager.dart'; 
import '../C3/market_manager.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 💡 ダミーデータの代わりに、本物のデータを格納する空のリストを用意
  List<Map<String, dynamic>> _myPosts = [];
  String _userName = ''; // 💡 ユーザー名を格納する変数
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // 画面が開かれたときに本物のデータを取得！
  }

  // 🎁 本物のデータをFirestoreから取得して合体させる関数
  Future<void> _fetchUserData() async {
    setState(() { _isLoading = true; });

    const targetUserId = 'dummy_user_123'; 

    // 💡 ユーザー名を取得
    final fetchedName = await UserManager().fetchUserName(targetUserId);

    final circles = await CircleManager().fetchMyCircles(targetUserId);
    final products = await MarketManager().fetchMyProducts(targetUserId);

    final List<Map<String, dynamic>> combinedPosts = [];
    for (var c in circles) { combinedPosts.add({'id': c.id, 'title': c.name, 'category': 'サークル', 'date': '登録済み', 'type': 'circle', 'imageUrl': c.imageUrl}); }
    for (var p in products) { combinedPosts.add({'id': p.id, 'title': p.title, 'category': '教材', 'date': '出品済み', 'type': 'market', 'imageUrl': p.imageUrl}); }
    
    /*
    for (var e in exams) {
      combinedPosts.add({
        'id': e.pastexamId, 'title': e.title, 'category': '過去問', 'date': '投稿済み', 'type': 'pastexam', 'imageUrl': e.fileUrls.isNotEmpty ? e.fileUrls.first : '', 
      });
    */

    setState(() {
      _userName = fetchedName; // 💡 取得した名前をセット
      _myPosts = combinedPosts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('プロフィール', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
          Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: OutlinedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ProfileEditScreen(currentName: _userName)),
                );
                if (result == true) {
                  _fetchUserData(); // 💡 プロフィール編集後に最新のデータを取得
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('プロフィールを編集', style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          Divider(thickness: 1, color: Colors.grey[200], height: 1),
          
          // ⑤ 過去の投稿一覧エリア
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
                          '過去の投稿 (${_myPosts.length}件)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  
                  // 💡 読み込み中くるくる ＆ リスト表示部分
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _myPosts.isEmpty
                        ? const Center(
                            child: Text('過去の投稿はありません', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
                          )
                        : ListView.builder(
                            itemCount: _myPosts.length,
                            itemBuilder: (context, index) {
                              final post = _myPosts[index];
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
                                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      post['category']!,
                                      style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    post['title']!,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(post['date']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Text('投稿の削除', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          content: Text('「${post['title']}」を本当に削除しますか？\n（※この操作は取り消せません）'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                // 🗑️ 本物の削除処理！
                                                final postId = post['id'];
                                                final postType = post['type'];
                                                final imageUrl = post['imageUrl'];

                                                if (postType == 'circle') {
                                                  await CircleManager().deleteCircle(postId, imageUrl);
                                                } else if (postType == 'market') {
                                                  await MarketManager().deleteProduct(postId, imageUrl);
                                                } else if (postType == 'pastexam'){
                                                  await PastExamRepository().deletePastExam(postId, imageUrl);
                                                }

                                                // ダイアログを閉じて、リストを再取得（更新）
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('「${post['title']}」を削除しました')),
                                                  );
                                                  _fetchUserData(); // 💡 削除後にリストを最新状態にする
                                                }
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
        onPressed: () { /* ログアウト処理は省略 */ },
        backgroundColor: Colors.red[400],
        elevation: 4,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text('ログアウト', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}