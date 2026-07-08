/// 学内情報共有システム — C4 取引・決済処理部
/// 教材カタログの読み取り専用リポジトリ（W13 一覧 / W14 詳細の表示用）
///
/// 取引の書き込み（在庫ロック等）は FirestoreItemRepository の責務。
/// ここは items の read（Rules で全員許可）だけを扱う。
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/models/transaction_models.dart';

/// items スキーマの確定値（functions/src/constants.ts と一致させること）。
const String _itemsCollection = 'items';
const String _fieldStatus = 'status';

/// 教材カタログの読み取り専用リポジトリ。
class ItemCatalogRepository {
  final FirebaseFirestore _firestore;

  ItemCatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection(_itemsCollection);

  /// 販売中の教材一覧を取得する（W13）。
  /// orderBy は複合インデックスが必要になるため付けない（初版方針）。
  Future<List<Item>> fetchOnSaleItems() async {
    try {
      final snapshot = await _items
          .where(_fieldStatus, isEqualTo: ItemStatus.onSale)
          .get();
      return snapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      throw _mapError(e);
    }
  }

  /// 教材1件を取得する（W14 表示時の最新化）。
  Future<Item> fetchItemById(String listingId) async {
    try {
      final doc = await _items.doc(listingId).get();
      final data = doc.data();
      if (data == null) {
        throw const C4Exception(404, '対象の教材が見つかりません。');
      }
      return Item.fromMap(data, doc.id);
    } on C4Exception {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapError(e);
    }
  }

  C4Exception _mapError(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
        return const C4Exception(503, '通信環境を確認してください。');
      default:
        return C4Exception(500, '教材情報の取得に失敗しました。(${e.code})');
    }
  }
}
