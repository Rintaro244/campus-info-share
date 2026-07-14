import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LecturePostScreen extends StatefulWidget {
  const LecturePostScreen({super.key});

  @override
  State<LecturePostScreen> createState() => _LecturePostScreenState();
}

class _LecturePostScreenState extends State<LecturePostScreen> {
  final nameController = TextEditingController();
  final teacherController = TextEditingController();
  final commentController = TextEditingController();
  
  // 💡 学部とジャンル（カテゴリ）の選択状態を管理
  String selectedFaculty = '工学部'; // 初期値を設定
  String selectedCategory = '英語';

  // 💡 一覧画面（リスト側）と完全に一致させた学部のリスト
  final faculties = ['工学部', 'システム理工学部', 'デザイン工学部', '建築学部', ];
  final categories = ['英語', '数理基礎', '人文教養', '体育健康', '専門'];

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
              onPressed: () => onRatingChanged(index + 1),
            );  
          }),
        ),
      ],
    );
  }

  Future<void> _submitReview() async {
    // 💡 facultyController.text.isEmpty のチェックは不要になったので削除！
    if (nameController.text.isEmpty || teacherController.text.isEmpty || commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての項目を入力してください')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('lecture').add({
        'lecture_name': nameController.text,
        'faculty': selectedFaculty, // 👈 ドロップダウンで選ばれた文字列を保存！
        'teacher_name': teacherController.text,
        'category': selectedCategory,
        'comment': commentController.text,
        'difficulty_rating': difficulty,
        'task_amount_rating': taskAmount,
        'pace_rating': pace,
        'created_at': FieldValue.serverTimestamp(),
        'uid': FirebaseAuth.instance.currentUser?.uid ?? '',// 👈 ログインしているユーザーのUIDを保存
      });

      print('🎉 統一された学部名で投稿しました！');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('❌ 投稿エラー: $e');
    }
  }

  int difficulty = 3;
  int taskAmount = 3;
  int pace = 3;

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
            const SizedBox(height: 15),
            
            // 💡 手書きのTextFieldから、ドロップダウンに変更！
            DropdownButtonFormField<String>(
              value: selectedFaculty,
              items: faculties.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) => setState(() => selectedFaculty = val!),
              decoration: const InputDecoration(labelText: '学部を選択', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: teacherController, 
              decoration: const InputDecoration(labelText: '担当の先生名を入力', border: OutlineInputBorder())
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => selectedCategory = val!),
              decoration: const InputDecoration(labelText: '授業のジャンルを選択', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            _buildStarRating('📊 授業難易度（星が多いほど難しい）', difficulty, (val) => setState(() => difficulty = val)),
            const SizedBox(height: 10),
            _buildStarRating('📊 課題の量（星が多いほど課題が多い）', taskAmount, (val) => setState(() => taskAmount = val)),
            const SizedBox(height: 10),
            _buildStarRating('📊 授業の進度（星が多いほど進みが速い）', pace, (val) => setState(() => pace = val)),
            const SizedBox(height: 20),
            TextField(
              controller: commentController, 
              maxLines: 5, 
              decoration: const InputDecoration(labelText: 'コメントを入力', border: OutlineInputBorder())
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