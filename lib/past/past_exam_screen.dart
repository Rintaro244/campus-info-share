import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'past_exam.dart';
import 'past_exam_controller.dart';
import 'past_exam_add_screen.dart';
import 'past_exam_detail_screen.dart';

class PastExamListScreen extends ConsumerStatefulWidget {
  const PastExamListScreen({super.key});

  @override
  ConsumerState<PastExamListScreen> createState() => _PastExamListScreenState();
}

class _PastExamListScreenState extends ConsumerState<PastExamListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void onExamTap(PastExam exam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PastExamDetailScreen(exam: exam),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(pastExamControllerProvider);

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('過去問検索・一覧', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
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
                    onChanged: (value) => ref.read(pastExamControllerProvider).updateSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: '例: 基礎数学、佐藤教授、期末試験',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: controller.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(pastExamControllerProvider).updateSearchQuery('');
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
                    initialValue: controller.selectedYear,
                    items: controller.yearOptions.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year == 'すべて' ? 'すべての年度' : '$year年度'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(pastExamControllerProvider).updateSelectedYear(value);
                      }
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
                '検索結果: ${controller.filteredExams.length} 件',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),

            Expanded(
              child: controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : controller.filteredExams.isEmpty
                      ? const Center(
                          child: Text(
                            '該当する過去問が見つかりません',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          itemCount: controller.filteredExams.length,
                          itemBuilder: (context, index) {
                            final exam = controller.filteredExams[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: InkWell(
                                onTap: () => onExamTap(exam),
                                borderRadius: BorderRadius.circular(8),
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
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blue[600],
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PastExamAddScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}