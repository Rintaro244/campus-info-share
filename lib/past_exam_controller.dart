import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // 💡 dart:ioの代わりにXFileを使うために追加！

// 同じフォルダ(lib)にあるファイルを読み込む
import 'past_exam.dart';
import 'past_exam_repository.dart';

// アプリのどこからでもControllerを呼び出せるようにする「プロバイダー（Riverpod）」
final pastExamControllerProvider = ChangeNotifierProvider((ref) {
  return PastExamController();
});

/// 画面の状態を管理し、検索や投稿のロジックを担当するController
class PastExamController extends ChangeNotifier {
  // Repository（Firebase通信係）のインスタンス化
  final PastExamRepository _repository = PastExamRepository();

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
    isLoading = true;
    notifyListeners();

    // RepositoryのStream（リアルタイム通信）を購読
    _repository.getPastExamsStream().listen((exams) {
      allExams = exams;
      
      // データから重複のない年度を抽出し、降順ソート
      final years = allExams
          .map((exam) => exam.year.toString())
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      
      yearOptions = ['すべて', ...years];
      
      // 選択中の年度がデータから消えた場合のセーフティ
      if (!yearOptions.contains(selectedYear)) {
        selectedYear = 'すべて';
      }

      isLoading = false;
      
      // データが届いたり更新されたら、自動でフィルターをかけ直す
      filterExams(); 
    }, onError: (error) {
      print("Firestore監視エラー: $error");
      isLoading = false;
      notifyListeners();
    });
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

    filteredExams = allExams.where((exam) {
      final matchesQuery = exam.title.toLowerCase().contains(query) ||
          exam.subjectName.toLowerCase().contains(query) ||
          exam.professorName.toLowerCase().contains(query);

      final matchesYear = selectedYear == 'すべて' || exam.year.toString() == selectedYear;

      return matchesQuery && matchesYear;
    }).toList();

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
    // 💡 Web対応：FileではなくXFileを受け取る！
    required List<XFile> imageFiles, 
  }) async {
    isSubmitting = true;
    notifyListeners(); // 投稿ボタンをローディング表示にする

    try {
      // 💡 Repository側のXFile対応版のメソッドを呼び出す
      List<String> fileUrls = await _repository.uploadFiles(imageFiles);

      // 保存用のデータ(PastExam)を作成
      final newExam = PastExam(
        pastexamId: '', // Firestoreが自動生成するので最初は空でOK
        title: title,
        year: year,
        subjectName: subjectName,
        professorName: professorName,
        fileUrls: fileUrls,
        createdAt: DateTime.now(),
        userId: 'dummy_user_id', // ※ログイン機能と連携したらここを適切なIDに変えます
      );

      // Firestoreにテキストデータを保存
      await _repository.addPastExam(newExam);

      isSubmitting = false;
      notifyListeners();
      return true; // 成功！
      
    } catch (e) {
      print("投稿エラー: $e");
      isSubmitting = false;
      notifyListeners();
      return false; // 失敗...
    }
  }
}