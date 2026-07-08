import 'package:flutter/material.dart';
import 'package:student_information_1/C3/user_manager.dart'; // 💡 環境に合わせて調整してください
import 'package:student_information_1/past/past_exam_repository.dart'; // 💡 過去問のリポジトリ
import 'profile_edit_screen.dart'; 
import '../C3/circle_manager.dart'; 
import '../C3/market_manager.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _myPosts = [];
  String _userName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // 画面が開かれたときに本物のデータを取得！
  }

  // 🎁 3つのデータをFirestoreから取得して1つのリストに合体させる関数
  Future<void> _fetchUserData() async {
    setState(() { _isLoading = true; });

    // TODO(本田さん): ログインモジュール完了後、ここを「現在ログイン中のユーザーUID」に差し替え
    const targetUserId = 'dummy_user_123'; 

    try {
      // 1. ユーザー名の取得
      final fetchedName = await UserManager().fetchUserName(targetUserId);

      // 2. サークル・フリマのデータ取得
      final circles = await CircleManager().fetchMyCircles(targetUserId);
      final products = await MarketManager().fetchMyProducts(targetUserId);

      // 3. 過去問データの取得（ Streamから1回だけリストを取得 ）
      final pastExamRepository = PastExamRepository();
      final allExams = await pastExamRepository.getPastExamsStream().first; 
      // 自分のIDのデータだけに絞り込む
      final myExams = allExams.where((exam) => exam.userId == targetUserId).toList();

      final List<Map<String, dynamic>> combinedPosts = [];

      // サークルの変換
      for (var c in circles) {
        combinedPosts.add({
          'id': c.id,
          'title': c.name,
          'category': 'サークル', 
          'date': '登録済み',
          'type': 'circle', // 判別用
          'imageUrl': c.imageUrl,
        });
      }

      // フリマの変換
      for (var p in products) {
        combinedPosts.add({
          'id': p.id,
          'title': p.title,
          'category': '教材', 
          'date': '出品済み',
          'type': 'market', // 判別用
          'imageUrl': p.imageUrl,
        });
      }

      // ✨ 過去問の変換（追加！）
      for (var exam in myExams) {
        combinedPosts.add({
          'id': exam.pastexamId,
          'title': exam.title,
          'category': '過去問', 
          // 日付を見やすくフォーマット
          'date': '${exam.createdAt.year}/${exam.createdAt.month}/${exam.createdAt.day}',
          'type': 'past_exam', // 判別用
          'fileUrls': exam.fileUrls, // 削除時に使う画像のURLリスト
        });
      }

      setState(() {
        _userName = fetchedName;
        _myPosts = combinedPosts;
        _isLoading = false;
      });
    } catch (e) {
      print('【エラー】データ取得失敗: $e');
      setState(() { _isLoading = false; });
    }
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
          const SizedBox(height: 16),
          Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: OutlinedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ProfileEditScreen(currentName: _userName))
                );
                
                if (result == true) {
                  _fetchUserData();
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
                                                // ✨ カテゴリに応じて削除処理を切り替え！
                                                final postId = post['id'];
                                                final postType = post['type'];

                                                if (postType == 'circle') {
                                                  await CircleManager().deleteCircle(postId, post['imageUrl']);
                                                } else if (postType == 'market') {
                                                  await MarketManager().deleteProduct(postId, post['imageUrl']);
                                                } else if (postType == 'past_exam') {
                                                  // 💡 過去問リポジトリの削除処理を呼び出す
                                                  final imageUrls = List<String>.from(post['fileUrls'] ?? []);
                                                  await PastExamRepository().deletePastExam(postId, imageUrls);
                                                }

                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('「${post['title']}」を削除しました')),
                                                  );
                                                  _fetchUserData(); // 削除後にリストを更新
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
        onPressed: () { 
          // TODO(本田さん): ここでC2 M3 ログアウトモジュールの処理を呼び出してください
          print("ログアウトしました");
        },
        backgroundColor: Colors.red[400],
        elevation: 4,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text('ログアウト', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}