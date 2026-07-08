import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lecture_post.dart'; // 投稿画面を開くために必要

class LectureListScreen extends StatelessWidget {
  const LectureListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('講義情報・口コミ一覧')),
      
      // 💡 StreamBuilderを使って、Firestoreの「lecture」コレクションをリアルタイム監視！
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lecture')
            .orderBy('created_at', descending: true) // 新しい投稿順に並べる
            .snapshots(),
        builder: (context, snapshot) {
          // 通信中のぐるぐる表示
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // データがまだ1件もないとき
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('まだ口コミがありません。\n右下の＋ボタンから最初の投稿をしてみましょう！', textAlign: TextAlign.center));
          }

          final docs = snapshot.data!.docs;

          // 口コミをリスト表示
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
             return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 授業名とカテゴリ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['lecture_name'] ?? '不明な授業', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Chip(label: Text(data['category'] ?? 'その他')),
                        ],
                      ),
                      const Divider(),
                      // 3軸評価の表示（簡易版として数字で表示）
                      Text('📊 難易度: ⭐ ${data['difficulty_rating'] ?? 0}  |  課題の量: ⭐ ${data['task_amount_rating'] ?? 0}  |  進度: ⭐ ${data['pace_rating'] ?? 0}'),
                      const SizedBox(height: 10),
                      // コメント
                      Text(data['comment'] ?? '', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    
      // 💡 右下に浮かぶ「＋」ボタン（これを押すと、あなたが作った投稿画面が開く！）
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LecturePostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}