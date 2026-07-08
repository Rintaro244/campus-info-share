/// 学内情報共有システム — C4 取引・決済処理部
/// PendingItemStore の単純実装（外部変数 c_pending_item_id をメモリ保持）
///
/// 購入フロー中に「いま手続き中の listingId」を 1 件だけ保持する。
/// W14→W15 で引き継ぎ、購入完了 or 中断時にクリアする（PurchaseFlowCoordinator が操作）。
/// 永続化は不要（アプリ再起動で破棄されてよい一時状態）。
library;

import 'package:student_information_1/payment/ui/payment_flow_navigation.dart';

/// メモリ上に c_pending_item_id を1個だけ保持する PendingItemStore。
class InMemoryPendingItemStore implements PendingItemStore {
  String? _pendingItemId;

  InMemoryPendingItemStore([this._pendingItemId]);

  @override
  String? get pendingItemId => _pendingItemId;

  @override
  set pendingItemId(String? value) => _pendingItemId = value;
}
