// lib/dummy_data.dart
import '/models/lecture.dart'; // 構造体のファイルを読み込む

// UIファイルから追い出したデータをここにまとめる
final List<Lecture> allLecturesMaster = [
  Lecture(
   id: '1',
    faculty: '工学部',
    course: '情報・通信工学課程情報工学コース',
    title: 'プログラミング基礎I',
    professor: '田中太郎',
    review: 'C言語の基礎です。課題は毎回出ます。',
    difficultyRating: 4,
    taskAmountRating: 5,
    paceRating: 3,
    
  ),
  Lecture(
   id: '1',
    faculty: 'システム理工学部',
    course: '情報課程IoTコース',
    title: 'プログラミング基礎I',
    professor: '田中次郎',
    review: 'C言語の基礎です。課題は毎回出ます。',
    difficultyRating: 4,
    taskAmountRating: 5,
    paceRating: 3,
  ),
];