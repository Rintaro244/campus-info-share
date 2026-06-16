import 'package:flutter/material.dart';
import 'circle_post_screen.dart'; // 次に作る投稿画面をインポート

class CircleSearchScreen extends StatefulWidget {
  const CircleSearchScreen({Key? key}) : super(key: key);

  @override
  State<CircleSearchScreen> createState() => _CircleSearchScreenState();
}

class _CircleSearchScreenState extends State<CircleSearchScreen> {
  // 検索条件の管理変数
  String _searchKeyword = '';
  String _selectedCampus = 'すべて'; // すべて, 豊洲, 大宮, 両方
  String _selectedCategory = 'すべて'; // すべて, 運動系, 文化系, その他

  // 設計書に基づくサークルのダミーデータ一覧
  final List<Map<String, String>> _allCircles = [
    {'name': '芝浦工大公式鉄道研究会', 'campus': '豊洲', 'category': '文化系', 'desc': '模型の展示や合宿を行っています！'},
    {'name': '硬式庭球部（テニス）', 'campus': '大宮', 'category': '運動系', 'desc': '初心者から経験者まで大歓迎です！🎾'},
    {'name': 'プログラミングサークルC3', 'campus': '両方', 'category': '文化系', 'desc': 'アプリやゲームを楽しく開発しています。'},
    {'name': '芝浦ストリートダンス部', 'campus': '豊洲', 'category': '運動系', 'desc': '学祭でのステージに向けて日々練習中！'},
    {'name': 'シバウラ軽音サークル', 'campus': '大宮', 'category': 'その他', 'desc': 'アコースティックからバンドまで幅広く活動。'},
  ];

  // 💡 設計書の要件：条件（キーワード、キャンパス、カテゴリ）で動的に絞り込む処理
  List<Map<String, String>> get _filteredCircles {
    return _allCircles.where((circle) {
      // ① キーワード絞り込み
      final matchKeyword = circle['name']!.contains(_searchKeyword);
      
      // ② キャンパス絞り込み (外部変数 c_session_campus 等を意識)
      final matchCampus = _selectedCampus == 'すべて' || 
                          circle['campus'] == _selectedCampus || 
                          circle['campus'] == '両方';

      // ③ カテゴリ絞り込み
      final matchCategory = _selectedCategory == 'すべて' || 
                            circle['category'] == _selectedCategory;

      return matchKeyword && matchCampus && matchCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredCircles;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('サークル・部活動検索', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. 検索キーワード入力欄
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'サークル名やキーワードを入力',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2 & 3. 選択式（ドロップダウン）フィルターエリア
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // 左側：キャンパス選択
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'キャンパス',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedCampus,
                        items: ['すべて', '豊洲', '大宮', '両方'].map((campus) {
                          return DropdownMenuItem(value: campus, child: Text(campus, style: const TextStyle(fontSize: 14)));
                        }).toList(),
                        onChanged: (value) {
                          setState(() { _selectedCampus = value!; });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.blue[50]?.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[100]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[400]!, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12), // ドロップダウン同士の間の隙間

                // 右側：カテゴリ選択
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'カテゴリ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: ['すべて', '運動系', '文化系', 'その他'].map((category) {
                          return DropdownMenuItem(value: category, child: Text(category, style: const TextStyle(fontSize: 14)));
                        }).toList(),
                        onChanged: (value) {
                          setState(() { _selectedCategory = value!; });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.green[50]?.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[100]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[400]!, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24, thickness: 1),

          // 4. サークル一覧表示エリア
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        '該当するデータが見つかりませんでした。', // 💡 設計書指定のエラーメッセージ文言
                        style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final circle = results[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Row(
                            children: [
                              Text(circle['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              _buildBadge(circle['campus']!, Colors.blue),
                              const SizedBox(width: 4),
                              _buildBadge(circle['category']!, Colors.green),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(circle['desc']!, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () {
                            // 本番では詳細画面(W9)へ遷移
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('「${circle['name']}」の詳細画面へ（開発中）')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // 5. 新規サークル投稿画面(W8)へのボタン
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CirclePostScreen()),
          );
        },
        backgroundColor: Colors.blue[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('サークルを登録', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // バッジ用カスタムウィジェット
  Widget _buildBadge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color[50], borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color[700], fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}