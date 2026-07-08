import 'package:cloud_firestore/cloud_firestore.dart';

class LectureManager {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('lecture');

  // 💡 自分が投稿した講義口コミの一覧を取得する
  Future<List<Map<String, dynamic>>> fetchMyLectures(String userId) async {
    try {
      
      // ユーザーID（uid）が一致するドキュメントだけを狙い撃ちで取得
      final snapshot = await _collection.where('uid', isEqualTo: userId).get();
      
      final List<Map<String, dynamic>> results = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        results.add({
          'id': doc.id, // ドキュメントID
          'title': data['lecture_name'] ?? '不明な授業',
          'category': '講義口コミ', // 💡 プロフィールでの表示用タグ
          'date': '投稿済み',
          'type': 'lecture', // 💡 タイプを判別する用
          'imageUrl': null, // 口コミには画像がないのでnull
        });
      }
      return results;
    } catch (e) {
      print('講義口コミ取得エラー: $e');
      return [];
    }
  }

  // 🗑️ プロフィール画面から口コミを直接削除する処理
  Future<void> deleteLecture(String docId) async {
    try {
      await _collection.doc(docId).delete();
    } catch (e) {
      print('講義口コミ削除エラー: $e');
    }
  }
}