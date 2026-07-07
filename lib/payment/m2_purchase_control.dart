/// 学内情報共有システム — C4 取引・決済処理部
/// M2 購入制御モジュール  担当: 木幡 陽介
library;

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';

/// 購入制御モジュール。同一教材への同時購入を防ぐため、C5 に在庫ロックと
/// 確定金額の取得を依頼する。トランザクション実行は C5 が担当する。
class PurchaseControlModule {
  final ItemRepository _itemRepository;

  const PurchaseControlModule(this._itemRepository);

  /// 購入手続きを開始し、在庫ロックと確定金額を取得する。
  /// 入力欠落は 400。在庫切れ409/未検出404/競合503 は C5 の例外を伝播。
  Future<LockResult> initiatePurchase({
    required String buyerId,
    required String listingId,
  }) async {
    if (buyerId.isEmpty || listingId.isEmpty) {
      throw const C4Exception(400, '購入手続きに必要な情報が不足しています。');
    }
    final result = await _itemRepository.lockItemForPurchase(
      listingId: listingId,
      buyerId: buyerId,
    );
    return result;
  }
}
