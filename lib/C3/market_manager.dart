import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'market_model.dart';

class MarketManager {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('products');
  final Reference _storageRef = FirebaseStorage.instance.ref().child('market_images');

  // 💡 修正：引数に userId を追加
  Future<bool> registerProduct({
    required String title,
    required int price,
    required String campus,
    required String condition,
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

      final newProduct = MarketModel(
        id: docRef.id,
        title: title,
        price: price,
        campus: campus,
        condition: condition,
        description: description,
        imageUrl: imageUrl, 
        userId: userId, // 💡 追加
      );

      await docRef.set(newProduct.toMap());
      return true;
    } catch (e) {
      print('【C3ロジック】登録エラー: $e');
      return false;
    }
  }

  // 🔍 （既存）検索関数はそのまま
  Future<List<MarketModel>> searchProducts({
    required String keyword,
    required String campus,
  }) async {
    try {
      Query query = _collection;
      if (campus != 'すべて') query = query.where('campus', isEqualTo: campus);

      final snapshot = await query.get();
      List<MarketModel> products = snapshot.docs.map((doc) => MarketModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

      if (keyword.isNotEmpty) {
        products = products.where((p) => p.title.contains(keyword) || p.description.contains(keyword)).toList();
      }
      return products;
    } catch (e) {
      return [];
    }
  }

  // 🎁 追加①：自分の出品した教材だけを取得する（マイページ用）
  Future<List<MarketModel>> fetchMyProducts(String targetUserId) async {
    try {
      final snapshot = await _collection.where('userId', isEqualTo: targetUserId).get();
      return snapshot.docs.map((doc) => MarketModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      print('【C3ロジック】マイ出品取得エラー: $e');
      return [];
    }
  }

  // 🗑️ 追加②：出品を取り消す（マイページ用）
  Future<bool> deleteProduct(String docId, String? imageUrl) async {
    try {
      await _collection.doc(docId).delete();
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          print('画像削除エラー: $e');
        }
      }
      return true;
    } catch (e) {
      print('【C3ロジック】削除エラー: $e');
      return false;
    }
  }
}