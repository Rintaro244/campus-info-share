import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

//同じフォルダ(lib)にあるファイルを読み込む
import 'past_exam.dart';
import 'past_exam_repository.dart';

//アプリのどこからでもControllerを呼び出せるようにする「プロバイダー（Riverpod）」
final pastExamControllerProvider = ChangeNotifierProvider((ref) {
  return PastExamController();
});

/// 画面の状態を管理し、検索や投稿のロジックを担当するController
class PastExamController extends ChangeNotifier {
  //いったんコメントアウト
  // final PastExamRepository _repository = PastExamRepository();

  // ==========================================
  // 1. 画面に表示するためのデータ（状態）
  // ==========================================
  List<PastExam> allExams = []; // Firestoreから取得した全データ
  List<PastExam> filteredExams = []; // 検索・フィルター後の表示用データ
  
  String searchQuery = ''; // 現在の検索キーワード
  String selectedYear = 'すべて'; // 現在選択されている年度
  List<String> yearOptions = ['すべて']; // ドロップダウンの選択肢
  
  bool isLoading = true; // 一覧の読み込み中ぐるぐるフラグ
  bool isSubmitting = false; // 投稿中のぐるぐるフラグ

  // ==========================================
  // 2. 初期化処理（データベースの監視スタート）
  // ==========================================
  PastExamController() {
    _listenToExams();
  }

  void _listenToExams() {
// エラー回避用：Firebaseの監視をストップし、ダミーデータを手動で入れる
    /* --- 元の通信コードは一旦コメントアウト（/* */ で囲んで無効化） ---
    _repository.getPastExamsStream().listen((exams) {
      // ... (元の処理)
    });
    -------------------------------------------------------------- */

    // 💡 UI確認用のダミーデータを直接代入
    allExams = [
      PastExam(
        pastexamId: 'dummy1',
        title: 'プログラミング基礎 期末テスト',
        year: 2024,
        subjectName: 'プログラミング基礎',
        professorName: '鳩山 太郎',
        fileUrls: [], // 画像なし
        createdAt: DateTime.now(),
        userId: 'test_user',
      ),
      PastExam(
        pastexamId: 'dummy2',
        title: 'ネットワーク論 中間',
        year: 2023,
        subjectName: 'ネットワーク論',
        professorName: '電大 次郎',
        fileUrls: [],
        createdAt: DateTime.now(),
        userId: 'test_user',
      ),
    ];

    // ダミーの年度選択肢を用意
    yearOptions = ['すべて', '2024', '2023', '2022'];
    isLoading = false;
    filterExams(); // 画面を更新
  }

  // ==========================================
  // 3. 検索・フィルター処理
  // ==========================================
  void updateSearchQuery(String query) {
    searchQuery = query;
    filterExams();
  }

  void updateSelectedYear(String year) {
    selectedYear = year;
    filterExams();
  }

  void filterExams() {
    final query = searchQuery.trim().toLowerCase();

    // 既存の美しい検索ロジックを移植
    filteredExams = allExams.where((exam) {
      final matchesQuery = exam.title.toLowerCase().contains(query) ||
          exam.subjectName.toLowerCase().contains(query) ||
          exam.professorName.toLowerCase().contains(query);

      final matchesYear = selectedYear == 'すべて' || exam.year.toString() == selectedYear;

      return matchesQuery && matchesYear;
    }).toList();

    // 画面に「データが変わったから再描画して！」と伝える
    notifyListeners();
  }

  // ==========================================
  // 4. 投稿処理
  // ==========================================
  Future<bool> submitExam({
    required String title,
    required int year,
    required String subjectName,
    required String professorName,
    required List<File> imageFiles,
  }) async {
    isSubmitting = true;
    notifyListeners(); // 投稿ボタンをローディング表示にする

    try {
      //エラー回避用：Firebaseへの保存処理をコメントアウト
      /*
      List<String> fileUrls = await _repository.uploadFiles(imageFiles);
      final newExam = PastExam(...);
      await _repository.addPastExam(newExam);
      */

      // 💡 代わりに2秒待って「投稿成功したフリ」をする
      await Future.delayed(const Duration(seconds: 2));

      isSubmitting = false;
      notifyListeners();
      return true; // 成功として画面を戻す
      
    } catch (e) {
      print("投稿エラー: $e");
      isSubmitting = false;
      notifyListeners();
      return false; // 失敗...
    }
  }
}