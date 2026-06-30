import 'package:cloud_firestore/cloud_firestore.dart';

class PastExam {
  String pastexamId; // FirestoreのドキュメントID
  String title; // タイトル
  int year; // 年度
  String subjectName; // 科目名
  String professorName; // 教授名
  
  // Firebase連携に向けて追加したプロパティ
  List<String> fileUrls; // 過去問の画像やPDFのURLリスト
  DateTime createdAt; // 投稿日時
  String userId; // 投稿したユーザーのID

  PastExam({
    required this.pastexamId,
    required this.title,
    required this.year,
    required this.subjectName,
    required this.professorName,
    required this.fileUrls,
    required this.createdAt,
    required this.userId,
  });

  //Firestoreから取得したデータ(DocumentSnapshot)を、
  //Flutterで扱いやすい [PastExam] オブジェクトに変換するファクトリメソッド
  factory PastExam.fromFirestore(DocumentSnapshot doc) {
    // doc.data() からMap形式でデータを取り出す
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return PastExam(
      pastexamId: doc.id, // FirestoreのドキュメントIDをそのままIDとして利用
      title: data['title'] ?? '',
      year: data['year'] ?? 0,
      subjectName: data['subjectName'] ?? '',
      professorName: data['professorName'] ?? '',
      // Firebaseの配列をList<String>に変換
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      // FirebaseのTimestamp型をFlutterのDateTime型に変換
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  //[PastExam] オブジェクトを、
  //Firestoreに保存できる形式(Map<String, dynamic>)に変換するメソッド
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'year': year,
      'subjectName': subjectName,
      'professorName': professorName,
      'fileUrls': fileUrls,
      // FlutterのDateTime型をFirebaseのTimestamp型に変換して保存
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }
}