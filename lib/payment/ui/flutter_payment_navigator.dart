/// 学内情報共有システム — C4 取引・決済処理部
/// PaymentNavigator の Flutter 実装（画面遷移の具体化）
library;

import 'package:flutter/material.dart';

import 'package:student_information_1/payment/ui/payment_flow_navigation.dart';

/// アプリ内の名前付きルート定義（W 番号と対応）。
class AppRoutes {
  static const String itemList = '/items'; // W13 教材一覧
  static const String itemDetail = '/items/detail'; // W14 教材詳細
  static const String paymentSelect = '/payment/select'; // W15 支払方法選択
  static const String cardEntry = '/payment/card'; // 決済カード入力画面
  static const String purchaseComplete = '/payment/complete'; // 購入完了画面

  const AppRoutes._();
}

/// 決済カード入力画面へ渡す引数。
@immutable
class CardEntryArgs {
  final String clientSecret;
  final String paymentIntentId;
  final int amount;

  const CardEntryArgs({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
  });
}

/// 購入（譲渡）完了画面へ渡す引数。transactionId は「出品者と連絡を取る」導線に使う。
@immutable
class PurchaseCompleteArgs {
  final String listingId;

  /// チャットルーム ID（= transactionId）。未確定なら null（ボタン非表示）。
  final String? transactionId;

  const PurchaseCompleteArgs({required this.listingId, this.transactionId});
}

/// PaymentNavigator の Flutter 実装。GlobalKey 経由で BuildContext を
/// 跨いだ非同期遷移に対応する。
class FlutterPaymentNavigator implements PaymentNavigator {
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const FlutterPaymentNavigator({
    required this.navigatorKey,
    required this.messengerKey,
  });

  NavigatorState? get _nav => navigatorKey.currentState;

  @override
  void goToCardEntry({
    required String clientSecret,
    required String paymentIntentId,
    required int amount,
  }) {
    _nav?.pushNamed(
      AppRoutes.cardEntry,
      arguments: CardEntryArgs(
        clientSecret: clientSecret,
        paymentIntentId: paymentIntentId,
        amount: amount,
      ),
    );
  }

  @override
  void goToPurchaseComplete({required String listingId, String? transactionId}) {
    _nav?.pushNamed(
      AppRoutes.purchaseComplete,
      arguments: PurchaseCompleteArgs(
        listingId: listingId,
        transactionId: transactionId,
      ),
    );
  }

  @override
  void backToItemDetail({required String reason}) {
    _nav?.popUntil(
      (route) => route.settings.name == AppRoutes.itemDetail || route.isFirst,
    );
  }

  @override
  void showError({required int code, required String message}) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('[$code] $message')),
    );
  }
}
