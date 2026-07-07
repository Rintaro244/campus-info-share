/// 学内情報共有システム — C5 外部連携・データアクセス処理部
/// Cloud Functions Callable の例外を C4Exception へ写像する共通処理
///
/// サーバ側 index.ts toHttpsError の写像（400→invalid-argument, 404→not-found,
/// 409→failed-precondition, 502/503→unavailable, 401→unauthenticated）の逆変換。
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'package:student_information_1/payment/models/transaction_models.dart';

/// Callable の呼び出しで使うリージョン（functions 側の region 指定と一致させる）。
const String functionsRegion = 'asia-northeast1';

/// FirebaseFunctionsException を C4Exception（設計書のステータスコード）へ写像する。
C4Exception mapFunctionsError(FirebaseFunctionsException e) {
  final message = e.message ?? '決済ゲートウェイとの連携に失敗しました。';
  switch (e.code) {
    case 'unauthenticated':
      return C4Exception(401, message);
    case 'invalid-argument':
      return C4Exception(400, message);
    case 'not-found':
      return C4Exception(404, message);
    case 'failed-precondition':
      return C4Exception(409, message);
    case 'unavailable':
      return C4Exception(503, message);
    default:
      return C4Exception(502, message);
  }
}
