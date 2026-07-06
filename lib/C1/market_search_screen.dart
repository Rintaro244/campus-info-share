// lib/C1/market_search_screen.dart

import 'package:flutter/material.dart';
import 'market_post_screen.dart';
// 👇 追加：C3のモデルとマネージャーをインポート
import '../C3/market_manager.dart';
import '../C3/market_model.dart';
import 'market_detail_screen.dart'; // 💡 詳細画面への遷移用にインポート

class MarketSearchScreen extends StatefulWidget {
  const MarketSearchScreen({Key? key}) : super(key: key);

  @override
  State<MarketSearchScreen> createState() => _MarketSearchScreenState();
}

class _MarketSearchScreenState extends State<MarketSearchScreen> {
  String _keyword = '';
  
  // 💡 ダミーデータをやめて、Firestoreから取得したデータを入れるリスト
  List<MarketModel> _items = [];
  bool _isLoading = false; // 読み込み中くるくる表示用

  @override
  void initState() {
    super.initState();
    _fetchItems(); // 画面が開いた瞬間にデータベースから取得！
  }

  // 💡 Firestoreからデータを取得する関数
  Future<void> _fetchItems() async {
    setState(() { _isLoading = true; });

    final results = await MarketManager().searchProducts(
  keyword: _keyword, // 💡 画面側で使っているキーワードの変数名
  campus: 'すべて',   // 💡 画面側で使っているキャンパスの変数名（※）
);

    setState(() {
      _items = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教材取引（フリーマーケット）')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(labelText: 'キーワードで教材を検索', prefixIcon: Icon(Icons.search)),
              onChanged: (val) {
                _keyword = val;
                _fetchItems(); // 文字が入力されるたびに再検索
              },
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) // 読み込み中はくるくる
                : _items.isEmpty
                    ? const Center(child: Text('出品されている教材がありません。'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              // 💡 値段を見やすく表示
                              trailing: Text('¥${item.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MarketDetailScreen(product: item),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 💡 出品画面へ移動し、戻ってきたときに「true」を受け取ったらリストを再読み込み！
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const MarketPostScreen()),
          );
          if (result == true) {
            _fetchItems();
          }
        },
        backgroundColor: Colors.orange[600],
        label: const Text('出品する', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}