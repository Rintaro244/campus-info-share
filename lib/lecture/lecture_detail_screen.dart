import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LectureDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const LectureDetailScreen({super.key, required this.data, required this.docId});

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> {
  late Map<String, dynamic> currentData;

  // 💡 いまログインしている人（仮のID）。
  // チームのログイン機能と合体した後は、ここを本物のログインIDに書き換えます！
  final String currentLoginUid = 'dummy_user_123';

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.data);
  }

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 24);
      }),
    );
  }

  Future<void> _deleteReview() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('クチコミの削除'),
        content: const Text('この投稿を完全に削除してもよろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('lecture').doc(widget.docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('クチコミを削除しました')));
          Navigator.pop(context);
        }
      } catch (e) {
        print('削除エラー: $e');
      }
    }
  }

  Future<void> _editReview() async {
    final commentController = TextEditingController(text: currentData['comment']);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('クチコミの編集'),
        content: TextField(
          controller: commentController,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'コメントを入力'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );

    if (confirm == true && commentController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('lecture').doc(widget.docId).update({
          'comment': commentController.text,
        });
        setState(() {
          currentData['comment'] = commentController.text;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('クチコミを更新しました')));
        }
      } catch (e) {
        print('更新エラー: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 投稿に紐づいているuidを取り出す（古いデータなどで空なら空文字）
    final String postUid = currentData['uid'] ?? '';

    // 💡 本人（IDが一致）のときだけ、編集・削除ボタンをアプバーに表示する！
    final List<Widget> actions = [];
    if (currentLoginUid == postUid) {
      actions.add(IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: _editReview));
      actions.add(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteReview));
      actions.add(const SizedBox(width: 8));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentData['lecture_name'] ?? '講義詳細'),
        actions: actions, // 💡 条件分岐したボタンのリストをここにセット！
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(currentData['lecture_name'] ?? '不明な授業', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                Chip(label: Text(currentData['category'] ?? 'その他')),
              ],
            ),
            const SizedBox(height: 10),
            Text('🏫 学部: ${currentData['faculty'] ?? '未登録'}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            Text('👤 担当先生: ${currentData['teacher_name'] ?? '未登録'}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const Divider(height: 40, thickness: 1),
            const Text('📊 講義の評価', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('授業難易度:')),
                _buildStars(currentData['difficulty_rating'] ?? 0),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('課題の量:')),
                _buildStars(currentData['task_amount_rating'] ?? 0),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('授業の進度:')),
                _buildStars(currentData['pace_rating'] ?? 0),
              ],
            ),
            const Divider(height: 40, thickness: 1),
            const Text('📝 クチコミ・対策', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
              child: Text(currentData['comment'] ?? 'コメントはありません。', style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}