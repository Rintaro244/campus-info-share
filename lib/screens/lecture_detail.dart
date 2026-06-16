import 'package:flutter/material.dart';
import 'lecture_post.dart';
// ★追加：Lectureクラスの設計図を読み込む（フォルダ構成に合わせて適宜 '../models/lecture.dart' などに変更してください）
import '../models/lecture.dart'; 

class LectureDetailScreen extends StatelessWidget {
  // ★修正：受け取るデータの型を Map<String, String> から Lecture に変更！
  final Lecture lecture;

  const LectureDetailScreen({super.key, required this.lecture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('講義詳細', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上部のアクションボタン（評価画面へ遷移）
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // ★修正：lecture['name'] ではなく lecture.title のようにドットで渡す
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LecturePostScreen(
                        className: lecture.title,
                        professorName: lecture.professor,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.star),
                label: const Text('この授業の評価を投稿する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            // 講義基本情報
            // ★修正：ドット表記で呼び出す
            Text(lecture.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('担当：${lecture.professor} 先生', style: const TextStyle(fontSize: 16, color: Colors.black87)),
            
            // ★追加：せっかくLectureクラスに項目が増えたので、学部や曜日なども表示しましょう！
            const SizedBox(height: 4),
            Text('学部/コース：${lecture.faculty} ${lecture.course}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 4),

            // 講義のレビュー・感想
            const Text('講義の感想・レビュー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                // ★修正：lecture['description'] から lecture.review に変更
                lecture.review.isNotEmpty ? lecture.review : 'レビューはまだありません。',
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ★追加：3つの星評価のプレビュー（仮デザイン）
            const Text('現在の評価', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildRatingRow('授業難易度', lecture.difficultyRating),
            _buildRatingRow('課題の量', lecture.taskAmountRating),
            _buildRatingRow('講義の進度', lecture.paceRating),
          ],
        ),
      ),
    );
  }

  // 星を表示するための簡単な補助メソッド
  Widget _buildRatingRow(String label, int rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 14))),
          Text('${'★' * rating}${'☆' * (5 - rating)}', style: const TextStyle(color: Colors.amber, fontSize: 16)),
        ],
      ),
    );
  }
}