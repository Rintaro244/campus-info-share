import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LecturePostScreen extends StatefulWidget {
  const LecturePostScreen({super.key});

  @override
  State<LecturePostScreen> createState() => _LecturePostScreenState();
}

class _LecturePostScreenState extends State<LecturePostScreen> {
  // 1. 入力内容を管理するためのコントローラー
  final nameController = TextEditingController();
  final commentController = TextEditingController();
  
  // 2. 選択されたカテゴリと3軸評価の初期値（最初は星3）
  String selectedCategory = '英語';
  int difficulty = 3;
  int taskAmount = 3;
  int pace = 3;

  // ドロップダウンに表示するカテゴリ一覧
  final categories = ['英語', '数理基礎', '人文教養', '体育健康', '専門'];

  // 3. 星評価の並び（UI）を自動で作るための共通パーツ
  Widget _buildStarRating(String label, int currentRating, Function(int) onRatingChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(index < currentRating ? Icons.star : Icons.star_border),
              color: Colors.amber,
              iconSize: 36,
              onPressed: () => onRatingChanged(index + 1), // タップした星の数（1〜5）に更新
            );
          }),
        ),
      ],
    );
  }

  // 4. 【ここに合体！】ボタンが押された時にFirestoreに3軸評価を保存する関数
  Future<void> _submitReview() async {
    // 授業名かコメントが空っぽなら、何もしない（エラー防止）
    if (nameController.text.isEmpty || commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('授業名とコメントを入力してください')),
      );
      return;
    }

    try {
      // Firestoreの「reviews」コレクションにデータを追加！
      await FirebaseFirestore.instance.collection('lecture').add({
        'lecture_name': nameController.text,
        'category': selectedCategory,
        'comment': commentController.text,
        'difficulty_rating': difficulty,   // 📊 難易度（1〜5）
        'task_amount_rating': taskAmount,  // 📊 課題の量（1〜5）
        'pace_rating': pace,               // 📊 進度（1〜5）
        'created_at': FieldValue.serverTimestamp(), // 投稿日時
      });

      print('🎉 3軸の評価口コミを投稿しました！');
      
      if (mounted) {
        Navigator.pop(context); // 投稿が成功したら、自動で前の画面に戻る
      }
    } catch (e) {
      print('❌ 投稿エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('口コミを投稿する')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(labelText: '授業名を入力', border: OutlineInputBorder())
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => selectedCategory = val!),
              decoration: const InputDecoration(labelText: '授業の種類を選択', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            
            // 3軸の星評価UIを配置
            _buildStarRating('📊 授業難易度（星が多いほど難しい）', difficulty, (val) => setState(() => difficulty = val)),
            const SizedBox(height: 10),
            _buildStarRating('📊 課題の量（星が多いほど課題が多い）', taskAmount, (val) => setState(() => taskAmount = val)),
            const SizedBox(height: 10),
            _buildStarRating('📊 授業の進度（星が多いほど進みが速い）', pace, (val) => setState(() => pace = val)),
            
            const SizedBox(height: 20),
            TextField(
              controller: commentController, 
              maxLines: 5, 
              decoration: const InputDecoration(labelText: 'コメントを入力（先生の特徴や対策など）', border: OutlineInputBorder())
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitReview, 
                child: const Text('投稿する', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}