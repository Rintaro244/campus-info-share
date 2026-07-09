/// 学内情報共有システム — C5 外部連携・データアクセス処理部
/// PaymentGatewayClient の Callable 具象（C5・M6 createPaymentIntent を呼ぶ）
///
/// 送信するのは listingId のみ。buyerId は認証トークン（request.auth.uid）、
/// 金額はサーバが items.price（正規価格）から算出する契約のため、
/// クライアントから金額・uid を送らない（改ざん余地を作らない）。
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';
import 'package:student_information_1/payment/services/callable_error_mapper.dart';

/// PaymentGatewayClient の Cloud Functions Callable 具象。
class CallablePaymentGatewayClient implements PaymentGatewayClient {
  final FirebaseFunctions _functions;

  CallablePaymentGatewayClient({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  @override
  Future<PaymentIntentResult> createPaymentIntent({
    required String listingId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createPaymentIntent')
          .call<Map<Object?, Object?>>({'listingId': listingId});
      return PaymentIntentResult.fromJson(
        Map<String, dynamic>.from(result.data),
      );
    } on FirebaseFunctionsException catch (e) {
      throw mapFunctionsError(e);
    } on FormatException catch (e) {
      throw C4Exception(502, '決済ゲートウェイの応答が不正です。(${e.message})');
    }
  }
}
