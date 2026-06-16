class Lecture {
  final String id;
  final String faculty;         // ★追加：学部（例：工学部）
  final String course;          // ★追加：コース（例：情報工学コース）
  final String title;           // 講義名
  final String professor;       // 教授名
  final String review;          // 講義の感想・レビュー
  final int difficultyRating;   // 授業難易度（1〜5）
  final int taskAmountRating;   // 課題の量（1〜5）
  final int paceRating;         // 講義の進度（1〜5）

  Lecture({
    required this.id,
    required this.faculty,
    required this.course,
    required this.title,
    required this.professor,
    required this.review,
    required this.difficultyRating,
    required this.taskAmountRating,
    required this.paceRating,
  });
}