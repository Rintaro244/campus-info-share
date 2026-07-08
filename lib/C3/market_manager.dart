// lib/C3/market_manager.dart
//
// 教材取引のデータアクセス（C4 取引・決済処理部に統合済み）。
// 旧実装は 'products' コレクション + MarketModel だったが、C4 の唯一の
// 教材コレクション 'items' + Item モデルに一本化した。
// 書き込みは Item.toCreateMap()、読み取りは Item.fromMap を返す。

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:student_information_1/payment/models/item.dart';

class MarketManager {
  // C4 の確定コレクション。旧 'products' は廃止。
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('items');
  final Reference _storageRef =
      FirebaseStorage.instance.ref().child('market_images');

  /// 出品（items への create）。
  /// sellerId は必ずログイン中の本人 uid を渡すこと（Rules が本人以外を弾く）。
  /// 初期状態は on_sale 固定・買い手なし。価格/タイトルの妥当性は呼び出し側
  /// （MarketValidator）で検証済みであることを前提とする。
  Future<bool> registerProduct({
    required String title,
    required int price,
    required String campus,
    required String condition,
    required String description,
    required String sellerId,
    Uint8List? imageBytes,
  }) async {
    try {
      final docRef = _collection.doc();
      final List<String> imageUrls = [];

      if (imageBytes != null) {
        final imageRef = _storageRef.child('${docRef.id}.jpg');
        await imageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrls.add(await imageRef.getDownloadURL());
      }

      final item = Item(
        listingId: docRef.id,
        title: title,
        description: description,
        price: price,
        status: ItemStatus.onSale,
        sellerId: sellerId,
        campus: campus,
        condition: condition,
        imageUrls: imageUrls,
      );

      await docRef.set(item.toCreateMap());
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('【C3ロジック】登録エラー: $e');
      return false;
    }
  }

  /// 販売中（on_sale）の教材を検索する。キャンパス絞り込み + タイトル/説明の
  /// キーワード部分一致（クライアント側）。
  Future<List<Item>> searchProducts({
    required String keyword,
    required String campus,
  }) async {
    try {
      Query query = _collection.where('status', isEqualTo: ItemStatus.onSale);
      if (campus != 'すべて') query = query.where('campus', isEqualTo: campus);

      final snapshot = await query.get();
      List<Item> products = snapshot.docs
          .map((doc) =>
              Item.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (keyword.isNotEmpty) {
        products = products
            .where((p) =>
                (p.title ?? '').contains(keyword) ||
                (p.description ?? '').contains(keyword))
            .toList();
      }
      return products;
    } catch (e) {
      return [];
    }
  }

  /// 自分の出品した教材だけを取得する（マイページ用）。
  Future<List<Item>> fetchMyProducts(String targetUserId) async {
    try {
      final snapshot =
          await _collection.where('sellerId', isEqualTo: targetUserId).get();
      return snapshot.docs
          .map((doc) =>
              Item.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('【C3ロジック】マイ出品取得エラー: $e');
      return [];
    }
  }

  /// 出品を取り消す（マイページ用）。
  /// ※ 現状 Rules は items の delete をクライアントに許可していないため実際には
  ///   失敗する。出品取消は別タスクでサーバ側対応予定（今回スコープ外）。
  Future<bool> deleteProduct(String docId, String? imageUrl) async {
    try {
      await _collection.doc(docId).delete();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // ignore: avoid_print
          print('画像削除エラー: $e');
        }
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('【C3ロジック】削除エラー: $e');
      return false;
    }
  }
}
