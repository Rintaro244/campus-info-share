import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'past_exam.dart';

import 'past_exam_controller.dart';
import 'past_exam_repository.dart';
import 'past_exam_screen.dart';

class PastExamDetailScreen extends ConsumerWidget {
  final PastExam exam;

  const PastExamDetailScreen({Key? key, required this.exam}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrls = exam.fileUrls; 

    return Scaffold(
      backgroundColor: Colors.grey[50], // 背景を少しグレーにしてカードを引き立たせる
      appBar: AppBar(
        title: const Text('過去問の詳細', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              // 削除確認ダイアログを表示
              final bool? confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('削除の確認'),
                  content: const Text('この過去問を削除してもよろしいですか？\n※この操作は取り消せません。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('削除する', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(pastExamControllerProvider).deleteExam(exam.pastexamId); 
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('削除しました'), 
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 基本情報セクション
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 年度タグ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${exam.year}年度',
                      style: TextStyle(color: Colors.blue[600], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // タイトル
                  Text(
                    exam.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 1, color: Colors.black12),
                  const SizedBox(height: 24),
                  
                  // 科目名
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 20, color: Colors.grey[500]),
                      const SizedBox(width: 12),
                      const Text('科目名:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exam.subjectName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 教授名
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 20, color: Colors.grey[500]),
                      const SizedBox(width: 12),
                      const Text('教授名:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exam.professorName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 2. 過去問の画像表示セクション
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '過去問の写真',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  
                  if (imageUrls.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: const Center(
                        child: Text('画像が登録されていません', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    // 画像を縦に綺麗に並べるリスト
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), // 親のスクロールと衝突しないようにする
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              // 画像読み込み中のぐるぐる
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  color: Colors.white,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              // 万が一エラーが出た場合の表示
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.redAccent),
                                        SizedBox(height: 8),
                                        Text('画像の読み込みに失敗しました', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}