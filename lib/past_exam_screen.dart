import 'package:flutter/material.dart';
import 'past_exam.dart';
import 'past_data.dart';

class PastExamListScreen extends StatefulWidget {
  const PastExamListScreen({Key? key}) : super(key: key);

  @override
  State<PastExamListScreen> createState() => _PastExamListScreenState();
}

class _PastExamListScreenState extends State<PastExamListScreen> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedYear = 'すべて';
  
  // 💡 追加: ドロップダウンの選択肢を保持するリスト
  final List<String> _yearOptions = ['すべて'];

  List<PastExam> _filteredExams = [];

  @override
  void initState() {
    super.initState();
    _filteredExams = List.from(pastExams);

    // 💡 追加: データから重複のない年度を抽出し、降順にソートしてリストに追加
    final years = pastExams
        .map((exam) => exam.year.toString())
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    
    _yearOptions.addAll(years);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterExams() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredExams = pastExams.where((exam) {
        final matchesQuery = exam.title.toLowerCase().contains(query) ||
            exam.subjectName.toLowerCase().contains(query) ||
            exam.professorName.toLowerCase().contains(query);

        final matchesYear = _selectedYear == 'すべて' || exam.year.toString() == _selectedYear;

        return matchesQuery && matchesYear;
      }).toList();
    });
  }

  void _onExamTap(PastExam exam) {
    _messengerKey.currentState?.removeCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('「${exam.title}」を選択しました（擬似処理）'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('過去問検索・一覧', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('キーワード検索', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => _filterExams(),
                    decoration: InputDecoration(
                      hintText: '例: 基礎数学、田中教授、期末試験',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _filterExams();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[600]!, width: 2), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('年度フィルター', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedYear,
                    // 💡 変更: 生成したリストを使う
                    items: _yearOptions.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year == 'すべて' ? 'すべての年度' : '$year年度'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value!;
                        _filterExams();
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(height: 32, thickness: 1, color: Colors.black12),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: Text(
                '検索結果: ${_filteredExams.length} 件',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),

            Expanded(
              child: _filteredExams.isEmpty
                  ? const Center(
                      child: Text(
                        '該当する過去問が見つかりません',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      itemCount: _filteredExams.length,
                      itemBuilder: (context, index) {
                        final exam = _filteredExams[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: InkWell(
                            onTap: () => _onExamTap(exam),
                            borderRadius: BorderRadius.circular(8),
                            // 💡 変更: Container を Ink にして波紋エフェクトを見えるように
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${exam.year}年度',
                                      style: TextStyle(color: Colors.blue[600], fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    exam.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.menu_book_rounded, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          exam.subjectName,
                                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          exam.professorName,
                                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
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
      ),
    );
  }
}