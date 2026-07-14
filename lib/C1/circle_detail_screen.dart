import 'package:flutter/material.dart';
import '../C3/circle_model.dart';

class CircleDetailScreen extends StatelessWidget {
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
            Text(
              circle.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
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
            
            const SizedBox(height: 32),
            circle.imageUrl != null && circle.imageUrl!.isNotEmpty
                ? Container(
                    width: double.infinity,
                    height: 300, // 💡 高さを300に制限
                    decoration: BoxDecoration(
                      color: Colors.black87, // 💡 背景を黒にして画像を引き締める
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      // 💡 fitを contain に変更して全体をきれいに収める
                      child: Image.network(
                        circle.imageUrl!,
                        fit: BoxFit.contain,
                      ),
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