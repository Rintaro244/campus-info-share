// lib/C1/market_search_screen.dart

import 'package:flutter/material.dart';
import 'market_post_screen.dart';

class MarketSearchScreen extends StatefulWidget {
  const MarketSearchScreen({Key? key}) : super(key: key);

  @override
  State<MarketSearchScreen> createState() => _MarketSearchScreenState();
}

class _MarketSearchScreenState extends State<MarketSearchScreen> {
  String _keyword = '';
  final List<Map<String, String>> _dummyItems = [
    {'title': '基本情報技術者 合格教本', 'price': '1500', 'desc': '書き込みなし、非常に綺麗な状態です。'},
    {'title': '理工系の微分積分学', 'price': '1200', 'desc': '1年の共通科目で使います。'},
    {'title': '詳解応用情報技術者 過去問題集', 'price': '2000', 'desc': '午前・午後ともに対策できます。'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredItems = _dummyItems.where((item) {
      return item['title']!.contains(_keyword) || item['desc']!.contains(_keyword);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('教材取引（フリーマーケット）')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(labelText: 'キーワードで教材を検索', prefixIcon: Icon(Icons.search)),
              onChanged: (val) => setState(() => _keyword = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(item['title']!),
                    subtitle: Text(item['desc']!),
                    trailing: Text('${item['price']} 円', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketPostScreen()));
        },
        label: const Text('出品する'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}