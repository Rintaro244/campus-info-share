import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'circle_model.dart';

class CircleManager {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('circles');
  final Reference _storageRef = FirebaseStorage.instance.ref().child('circle_images');

  // 💡 修正：引数に userId を追加
  Future<bool> registerCircle({
    required String name,
    required String campus,
    required String category,
    required String description,
    required String userId, // 👈 追加
    Uint8List? imageBytes, 
  }) async {
    try {
      final docRef = _collection.doc();
      String? imageUrl;

      if (imageBytes != null) {
        final imageRef = _storageRef.child('${docRef.id}.jpg');
        await imageRef.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await imageRef.getDownloadURL();
      }

      final newCircle = CircleModel(
        id: docRef.id,
        name: name,
        campus: campus,
        category: category,
        description: description,
        imageUrl: imageUrl, 
        userId: userId, // 💡 追加
      );

      await docRef.set(newCircle.toMap());
      return true;
    } catch (e) {
      print('【C3ロジック】登録エラー: $e');
      return false;
    }
  }

  // 🔍 （既存）検索関数はそのまま
  Future<List<CircleModel>> searchCircles({
    required String keyword,
    required String campus,
    required String category,
  }) async {
    try {
      Query query = _collection;
      if (campus != 'すべて') query = query.where('campus', isEqualTo: campus);
      if (category != 'すべて') query = query.where('category', isEqualTo: category);

      final snapshot = await query.get();
      List<CircleModel> circles = snapshot.docs.map((doc) => CircleModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

      if (keyword.isNotEmpty) {
        circles = circles.where((c) => c.name.contains(keyword) || c.description.contains(keyword)).toList();
      }
      return circles;
    } catch (e) {
      return []; 
    }
  }

  // 🎁 追加①：自分のサークルだけを取得する（マイページ用）
  Future<List<CircleModel>> fetchMyCircles(String targetUserId) async {
    try {
      final snapshot = await _collection.where('userId', isEqualTo: targetUserId).get();
      return snapshot.docs.map((doc) => CircleModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      print('【C3ロジック】マイサークル取得エラー: $e');
      return [];
    }
  }

  // 🗑️ 追加②：サークルを削除する（マイページ用）
  Future<bool> deleteCircle(String docId, String? imageUrl) async {
    try {
      // 1. Firestoreから文字データを消す
      await _collection.doc(docId).delete();
      
      // 2. Storageから画像データも消す（ゴミが残らない親切設計！）
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          print('画像削除エラー(無視してOK): $e');
        }
      }
      return true;
    } catch (e) {
      print('【C3ロジック】削除エラー: $e');
      return false;
    }
  }
}