import 'package:flutter/material.dart';
import '../C3/circle_model.dart';

class CircleDetailScreen extends StatelessWidget {
  // 💡 前の画面（一覧）から渡されるサークルデータを受け取る箱
  final CircleModel circle;

  const CircleDetailScreen({Key? key, required this.circle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サークル詳細'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 サークル名
            Text(
              circle.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // 💡 キャンパスとカテゴリのタグ
            Row(
              children: [
                Chip(
                  label: Text(circle.campus),
                  backgroundColor: Colors.blue[50],
                  labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(circle.category),
                  backgroundColor: Colors.pink[50],
                  labelStyle: TextStyle(color: Colors.pink[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 💡 紹介文エリア
            const Text(
              'サークル紹介',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              circle.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            
            // ⚠️ 画像表示エリア（画像アップロード機能を作ったらここに表示します！）
            const SizedBox(height: 32),
            // 💡 画像URLがあればネットワークから画像を表示、なければグレーの箱を表示
            circle.imageUrl != null && circle.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      circle.imageUrl!,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover, // 画像をいい感じに切り抜いて枠に収める
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('画像はありません', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
            
          ],
        ),
      ),
    );
  }
}