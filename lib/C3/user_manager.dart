import 'package:cloud_firestore/cloud_firestore.dart';

class UserManager {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('users');

  // 👤 ユーザー名を取得する
  Future<String> fetchUserName(String userId) async {
    try {
      final doc = await _collection.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? '未設定ユーザー';
      } else {
        // まだデータがない（初回登録時など）場合は、デフォルトの名前を保存しておく
        await _collection.doc(userId).set({'name': '芝浦 太郎'});
        return '芝浦 太郎';
      }
    } catch (e) {
      print('ユーザー取得エラー: $e');
      return 'エラー';
    }
  }

  // ✏️ ユーザー名を更新する
  Future<bool> updateUserName(String userId, String newName) async {
    try {
      // SetOptions(merge: true) にすることで、他のデータ（アイコンなど）を消さずに名前だけ上書きできます
      await _collection.doc(userId).set({'name': newName}, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('ユーザー更新エラー: $e');
      return false;
    }
  }
}