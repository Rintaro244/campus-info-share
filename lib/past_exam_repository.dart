import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'past_exam.dart';

class PastExamRepository {
  // Firebaseの操作用インスタンスを用意
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  //過去問の一覧をFirestoreからリアルタイムに取得する（閲覧機能用）
  //投稿日時（createdAt）が新しい順に並び替えて取得します
  Stream<List<PastExam>> getPastExamsStream() {
    return _firestore
        .collection('past_exams')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          // 届いたドキュメントのリストを、1件ずつPastExamオブジェクトに変換してリストにする
          return snapshot.docs
              .map((doc) => PastExam.fromFirestore(doc))
              .toList();
        });
  }

  //選択された複数の画像ファイルを Firebase Storage にアップロードする（投稿機能用）
  //アップロードが完了したら、それぞれの「画像のURL（インターネット上のリンク）」をリストにして返します
  Future<List<String>> uploadFiles(List<File> files) async {
    List<String> imageUrls = [];

    for (var file in files) {
      // ファイル名が重複しないように、現在の時間（ミリ秒）をファイル名にする
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Storage上の保存先パスを設定（例: past_exams/1719660000000.jpg）
      Reference ref = _storage.ref().child('past_exams').child(fileName);
      
      // ファイルをアップロード
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      
      // アップロードしたファイルのURL（ダウンロードURL）を取得してリストに追加
      String downloadUrl = await snapshot.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  /// 💡 過去問のテキストデータ（タイトルや科目名など）をFirestoreに保存する（投稿機能用）
  Future<void> addPastExam(PastExam exam) async {
    // 'past_exams' コレクションに新しいドキュメントを追加
    await _firestore.collection('past_exams').add(exam.toFirestore());
  }
}