/// 学内情報共有システム — C5 外部連携・データアクセス処理部
/// FreeTransferClient の Callable 具象（fulfillFreeTransfer を呼ぶ）
///
/// 0円（無料譲渡）の確定。M2 の在庫ロック通過後に呼ぶこと。
/// サーバ側は冪等（本人へ確定済みなら already_fulfilled で成功応答）。
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';
import 'package:student_information_1/payment/services/callable_error_mapper.dart';

/// FreeTransferClient の Cloud Functions Callable 具象。
class CallableFreeTransferClient implements FreeTransferClient {
  final FirebaseFunctions _functions;

  CallableFreeTransferClient({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  @override
  Future<String> fulfillFreeTransfer({required String listingId}) async {
    try {
      final result = await _functions
          .httpsCallable('fulfillFreeTransfer')
          .call<Map<Object?, Object?>>({'listingId': listingId});
      final status = result.data['status'];
      if (status is! String) {
        throw const C4Exception(502, '無料譲渡の応答が不正です。');
      }
      return status; // 'fulfilled' | 'already_fulfilled'
    } on FirebaseFunctionsException catch (e) {
      throw mapFunctionsError(e);
    }
  }
}
