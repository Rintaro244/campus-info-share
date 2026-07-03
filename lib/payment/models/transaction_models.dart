/// 学内情報共有システム — C4 取引・決済処理部
/// データモデル定義（内部設計書 C4 の入出力データ型）
library;

/// 在庫ロック（M2 / C5 lockItemForPurchase）の結果。
class LockResult {
  /// ロック成功ステータス文字列（例: "locked"）。
  final String status;

  /// C5 経由で取得した正確な販売価格（決済金額の確定用）。円単位。
  final int amount;

  const LockResult({required this.status, required this.amount});

  factory LockResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final amount = json['amount'];
    if (status is! String) {
      throw const FormatException('LockResult.status must be a String');
    }
    if (amount is! int) {
      throw const FormatException('LockResult.amount must be an int');
    }
    return LockResult(status: status, amount: amount);
  }

  Map<String, dynamic> toJson() => {'status': status, 'amount': amount};
}

/// PaymentIntent 生成（M3 / C5 createPaymentIntent）の結果。
class PaymentIntentResult {
  /// Stripe から発行されたクライアントシークレット（決済用暗号化キー）。
  final String clientSecret;

  /// Stripe 側で生成された一意の決済意図 ID。
  final String paymentIntentId;

  const PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
  });

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    final clientSecret = json['clientSecret'];
    final paymentIntentId = json['paymentIntentId'];
    if (clientSecret is! String || paymentIntentId is! String) {
      throw const FormatException(
        'PaymentIntentResult requires String clientSecret and paymentIntentId',
      );
    }
    return PaymentIntentResult(
      clientSecret: clientSecret,
      paymentIntentId: paymentIntentId,
    );
  }

  Map<String, dynamic> toJson() => {
        'clientSecret': clientSecret,
        'paymentIntentId': paymentIntentId,
      };
}

/// C4 のドメイン例外。HTTP 風ステータスコードを保持する。
class C4Exception implements Exception {
  /// 設計書のエラー処理に対応するコード（401/400/404/409/500/502/503）。
  final int code;
  final String message;

  const C4Exception(this.code, this.message);

  @override
  String toString() => 'C4Exception($code): $message';
}

/// 決済フロー全体の進行状態。
enum PurchaseStage {
  locking,
  creatingIntent,
  readyForPayment,
  aborted,
}

/// M2→M3 を通したフロント向けの最終成果物。
class PurchaseSession {
  final PurchaseStage stage;
  final String listingId;
  final int? amount;
  final String? clientSecret;
  final String? paymentIntentId;

  const PurchaseSession({
    required this.stage,
    required this.listingId,
    this.amount,
    this.clientSecret,
    this.paymentIntentId,
  });

  bool get canProceedToPayment =>
      stage == PurchaseStage.readyForPayment &&
      clientSecret != null &&
      paymentIntentId != null;
}
