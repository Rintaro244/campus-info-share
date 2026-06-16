import 'package:flutter/material.dart';

class LecturePostScreen extends StatefulWidget {
  // ★重要：前の画面から授業名と教授名を受け取る仕組み
  final String className;
  final String professorName;

  const LecturePostScreen({
    super.key,
    required this.className,
    required this.professorName,
  });

  @override
  State<LecturePostScreen> createState() => _LecturePostScreenState();
}

class _LecturePostScreenState extends State<LecturePostScreen> {
  final _commentController = TextEditingController();

  // ★変更点：3つの評価項目に対応する状態変数
  int _difficultyRating = 3; // 授業難易度
  int _taskAmountRating = 3; // 課題の量
  int _paceRating = 3;       // 講義の進度

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitPost() {
    final comment = _commentController.text.trim();

    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントを入力してください。')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('投稿の確認'),
          content: Text('${widget.className} の評価を投稿しますか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // ダイアログを閉じる
                
                // TODO: ここで選択された3つの星（_difficultyRating, _taskAmountRating, _paceRating）を保存する
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('投稿が完了しました！')),
                );
                Navigator.pop(context); // 投稿画面を閉じる
              },
              child: const Text('投稿する'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('講義情報の投稿', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 授業名（自動入力・編集不可）
            const Text('授業名', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: widget.className),
              readOnly: true, // ユーザーが変更できないようにロック
              decoration: InputDecoration(
                fillColor: Colors.grey.shade200,
                filled: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 担当教員名（自動入力・編集不可）
            const Text('担当教員名', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: '${widget.professorName} 先生'),
              readOnly: true, // ロック
              decoration: InputDecoration(
                fillColor: Colors.grey.shade200,
                filled: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(thickness: 1),
            const SizedBox(height: 12),

            // ★項目1：授業難易度
            _buildRatingDropdown(
              label: '授業難易度 *',
              value: _difficultyRating,
              onChanged: (val) => setState(() => _difficultyRating = val ?? 3),
            ),
            const SizedBox(height: 16),

            // ★項目2：課題の量
            _buildRatingDropdown(
              label: '課題の量 *',
              value: _taskAmountRating,
              onChanged: (val) => setState(() => _taskAmountRating = val ?? 3),
            ),
            const SizedBox(height: 16),

            // ★項目3：講義の進度
            _buildRatingDropdown(
              label: '講義の進度 *',
              value: _paceRating,
              onChanged: (val) => setState(() => _paceRating = val ?? 3),
            ),
            const SizedBox(height: 24),

            // コメント入力
            const Text('講義の感想・コメント *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 5,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'テストの傾向や、課題の量などについて自由に記入してください。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 投稿ボタン
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitPost,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                child: const Text('投稿内容を確認する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ドロップダウンをきれいに並べるための共通部品
  Widget _buildRatingDropdown({
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: value,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [1, 2, 3, 4, 5].map((int val) {
            return DropdownMenuItem<int>(
              value: val,
              child: Text('${'★' * val}${'☆' * (5 - val)} ($val)'),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}