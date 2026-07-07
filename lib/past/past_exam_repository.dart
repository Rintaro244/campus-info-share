import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // 💡 Uint8List（バイトデータ）を使うために追加
import 'package:image_picker/image_picker.dart'; // 💡 File の代わりに XFile を使うために追加

import 'past_exam.dart';

class PastExamRepository {
  // Firebaseの操作用インスタンスを用意
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 過去問の一覧をFirestoreからリアルタイムに取得する（閲覧機能用）
  Stream<List<PastExam>> getPastExamsStream() {
    return _firestore
        .collection('past_exams')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PastExam.fromFirestore(doc))
              .toList();
        });
  }

  // 引数を List<File> から List<XFile> に変更！
  Future<List<String>> uploadFiles(List<XFile> files) async {
    List<String> imageUrls = [];

    for (var file in files) {
      // ファイル名が重複しないように、現在の時間（ミリ秒）をファイル名にする
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Storage上の保存先パスを設定
      Reference ref = _storage.ref().child('past_exams').child(fileName);
      
      // Webでもスマホでも100%動く「putData」に書き換え
      // ファイルの中身を数字の羅列（バイトデータ）として読み込み、アップロードします
      Uint8List bytes = await file.readAsBytes();
      UploadTask uploadTask = ref.putData(bytes);
      TaskSnapshot snapshot = await uploadTask;
      
      // アップロードしたファイルのURLを取得してリストに追加
      String downloadUrl = await snapshot.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  /// 過去問のテキストデータをFirestoreに保存する
  Future<void> addPastExam(PastExam exam) async {
    await _firestore.collection('past_exams').add(exam.toFirestore());
  }
}