import 'package:flutter/material.dart';
import 'lecture_search.dart';

class LectureFilterScreen extends StatefulWidget {
  const LectureFilterScreen({super.key});

  @override
  State<LectureFilterScreen> createState() => _LectureFilterScreenState();
}

class _LectureFilterScreenState extends State<LectureFilterScreen> {
  // ==========================================
  // ★ ここに【学部】と【それに属するコース】をセットで打ち込んでください！
  // ==========================================
  final Map<String, List<String>> _universityData = {
    '工学部': [
      '機械工学課程基幹機械コース',
      '機械工学課程先進機械コース',
      '物質化学課程環境・物質工学コース',
      '物質化学課程環境・生命工学コース',
      '電気電子工学課程電気・ロボット工学コース',
      '電気電子工学課程先端電子工学コース',
      '情報・通信工学課程情報通信コース',
      '情報・通信工学課程情報工学コース',
      '土木工学課程都市・環境コース',
      '先進国際課程',
    ],
    'デザイン工学部': [
      '社会情報システム',
      'UXコース',
      'プロダクトコース',
    ],
    'システム理工学部': [
      '情報課程IoTコース',
      '情報課程ソフトウェアコース',
      '情報課程メディア',
      '情報課程データサイエンスコース',
      '機械・電気課程機械・電気コース',
      '建築・環境課程建築コース',
      '建築・環境課程環境・都市コース',
      '生命科学課程生命科学コース',
      '生命科学課程医工学コース',
      '生命科学課程スポーツ工学コース',
      '数理科学課程数理科学コース',
    ],
    '建築学部': [
      '先進的プロジェクトデザインコース',
      '空間・建築デザインコース',
      '都市建築デザインコース',
    ],
  };

  // ユーザーが選択した値を管理する変数
  late String _selectedFaculty;
  late String _selectedCourse;

  @override
  void initState() {
    super.initState();
    // 最初に画面が開いたときは、Mapの1番目の学部と、その学部の1番目のコースを自動セット
    _selectedFaculty = _universityData.keys.first; // 例: '工学部'
    _selectedCourse = _universityData[_selectedFaculty]!.first; // 例: '情報工学コース'
  }

  @override
  Widget build(BuildContext context) {
    // 現在選択されている学部に対応するコースのリストを自動取得
    List<String> currentCourseList = _universityData[_selectedFaculty]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('講義検索・絞り込み', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '調べたい学部とコースを選択してください。',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 32),

            // 1. 学部選択ドロップダウン
            const Text('学部 *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedFaculty,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              // Mapの「キー（学部名）」をループして選択肢を作る
              items: _universityData.keys.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newFaculty) {
                setState(() {
                  _selectedFaculty = newFaculty!;
                  // ★超重要：学部が変わったら、コースの選択肢を新しい学部の「1番目のコース」に自動リセット！
                  _selectedCourse = _universityData[_selectedFaculty]!.first;
                });
              },
            ),
            const SizedBox(height: 24),

            // 2. コース選択ドロップダウン（学部に連動して中身が変わる）
            const Text('コース / 学科 *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              // 現在の学部に属するコースのリストを使って選択肢を作る
              items: currentCourseList.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newCourse) {
                setState(() {
                  _selectedCourse = newCourse!;
                });
              },
            ),
            const SizedBox(height: 40),

            // 3. 検索するボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LectureSearchScreen(
                        faculty: _selectedFaculty,
                        course: _selectedCourse,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                child: const Text('この条件で検索する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}