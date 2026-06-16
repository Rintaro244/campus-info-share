import 'package:flutter/material.dart';
import 'lecture_detail.dart';
// ★修正：フォルダを遡って(..)モデルとデータを読み込む
import '../models/lecture.dart'; 
import '../data/data.dart'; 

class LectureSearchScreen extends StatefulWidget {
  final String faculty;
  final String course;

  const LectureSearchScreen({
    super.key,
    required this.faculty,
    required this.course,
  });

  @override
  State<LectureSearchScreen> createState() => _LectureSearchScreenState();
}

class _LectureSearchScreenState extends State<LectureSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // ★追加：画面に実際に表示する用のリスト（空っぽで準備）
  List<Lecture> _displayedLectures = [];

  @override
  void initState() {
    super.initState();
    // ★追加：画面が開いた瞬間に、data.dart の全データから学部・コースで絞り込む
    _filterLecturesByDepartment();
  }

  void _filterLecturesByDepartment() {
    // ※ data.dart の中のリスト名が「allLecturesMaster」であると仮定しています
    _displayedLectures = allLecturesMaster.where((lecture) {
      return lecture.faculty == widget.faculty && 
             lecture.course == widget.course;
    }).toList();
  }

  void _performSearch() {
    final keyword = _searchController.text.trim();

    if (keyword.length > 50) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('入力文字が多すぎます。')),
      );
      return;
    }
    
    setState(() {
      // 検索時は一旦リストを学部・コースでリセットしてから、キーワードで絞り直す
      _filterLecturesByDepartment();
      
      if (keyword.isNotEmpty) {
        _displayedLectures = _displayedLectures.where((lecture) {
          return lecture.title.contains(keyword) || 
                 lecture.professor.contains(keyword);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.faculty} ${widget.course}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '講義名や教員名で検索...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _performSearch, child: const Text('検索')),
              ],
            ),
          ),
          // リスト表示
          Expanded(
            // ★修正：_lectureList ではなく _displayedLectures を使う
            child: _displayedLectures.isEmpty
              ? const Center(child: Text('該当する講義が見つかりません。'))
              : ListView.builder(
              itemCount: _displayedLectures.length,
              itemBuilder: (context, index) {
                final lecture = _displayedLectures[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LectureDetailScreen(lecture: lecture),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ★修正：['name'] ではなく .title のようにドットで呼び出す
                              Text('授業名: ${lecture.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text('担当教員: ${lecture.professor} 先生', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ],
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}