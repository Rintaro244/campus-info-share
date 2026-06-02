class Lecture {
  final String id;
  final String title;       // 講義名
  final String professor;   // 教授名
  final String dayOfWeek;   // 曜日
  final int period;         // 時限
  final String review;      // 講義の感想・レビュー
  final double rating;      // おすすめ度（星の数など）

  Lecture({
    required this.id,
    required this.title,
    required this.professor,
    required this.dayOfWeek,
    required this.period,
    required this.review,
    required this.rating,
  });
}