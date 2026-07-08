import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lecture_post.dart';
import 'package:student_information_1/lecture/lecture_detail_screen.dart';

class LectureListScreen extends StatefulWidget {
  const LectureListScreen({super.key});

  @override
  State<LectureListScreen> createState() => _LectureListScreenState();
}

class _LectureListScreenState extends State<LectureListScreen> {
  // 🔍 検索・絞り込み用の状態管理変数
  String _searchQuery = '';      // 授業名・先生名の検索文字
  String _selectedFaculty = 'すべて'; // 選択された学部
  String _selectedCategory = 'すべて'; // 選択されたジャンル

  // 絞り込み用の選択肢リスト
  final List<String> _faculties = ['すべて', '工学部', 'システム理工学部', 'デザイン工学部', '建築学部', ];
  final List<String> _categories = ['すべて', '英語', '数理基礎', '人文教養', '体育健康', '専門'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('講義情報・口コミ一覧')),
      body: Column(
        children: [
          // ==========================================
          // 🔍 検索・絞り込みパネルエリア
          // ==========================================
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            child: Column(
              children: [
                // ① 授業名・先生名の入力バー
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: '授業名または先生名で検索...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                
                // ② 学部 と ジャンル の絞り込みドロップダウン（横並び）
                Row(
                  children: [
                    // 学部選択
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFaculty,
                        decoration: const InputDecoration(labelText: '学部', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        items: _faculties.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedFaculty = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ジャンル選択
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'ジャンル', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // ==========================================
          // 📜 口コミリスト表示エリア
          // ==========================================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lecture')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('まだ口コミがありません。'));
                }

                // 💡 取得したドキュメントを条件に沿ってフィルタリング（絞り込み）する
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final lectureName = (data['lecture_name'] ?? '').toString().toLowerCase();
                  final teacherName = (data['teacher_name'] ?? '').toString().toLowerCase();
                  final faculty = data['faculty'] ?? '';
                  final category = data['category'] ?? '';

                  // キーワード検索（授業名か先生名に部分一致するか）
                  final matchesSearch = lectureName.contains(_searchQuery) || teacherName.contains(_searchQuery);
                  
                  // 学部絞り込み
                  final matchesFaculty = _selectedFaculty == 'すべて' || faculty == _selectedFaculty;
                  
                  // ジャンル絞り込み
                  final matchesCategory = _selectedCategory == 'すべて' || category == _selectedCategory;

                  // すべての条件をクリアしたものだけ残す！
                  return matchesSearch && matchesFaculty && matchesCategory;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('条件に合う口コミが見つかりません 🔍'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    //final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final doc = filteredDocs[index]; // 👈 docs[index] を一旦変数にする
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LectureDetailScreen(data: data,
                            docId: filteredDocs[index].id,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(data['lecture_name'] ?? '不明な授業', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Chip(label: Text(data['category'] ?? 'その他')),
                                ],
                              ),
                              Text('🏫 ${data['faculty'] ?? '未登録'}  |  👤 先生: ${data['teacher_name'] ?? '未登録'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              const Divider(),
                              Text('📊 難易度: ⭐ ${data['difficulty_rating'] ?? 0}  |  課題: ⭐ ${data['task_amount_rating'] ?? 0}  |  進度: ⭐ ${data['pace_rating'] ?? 0}'),
                              const SizedBox(height: 10),
                              Text(
                                data['comment'] ?? '', 
                                style: const TextStyle(color: Colors.black87), 
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
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