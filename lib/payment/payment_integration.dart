/// 学内情報共有システム — C4 取引・決済処理部
/// アプリ本体（main.dart）との統合ポイント
///
/// main.dart はこのファイルだけを import すればよい:
///   MaterialApp(
///     navigatorKey: paymentNavigatorKey,
///     scaffoldMessengerKey: paymentMessengerKey,
///     onGenerateRoute: onGeneratePaymentRoute,
///     ...
///   )
/// onGeneratePaymentRoute は C4 のルート名以外には null を返すため、
/// 既存機能（スポット等）の匿名 MaterialPageRoute 遷移には影響しない。
library;

import 'package:flutter/material.dart';

import 'package:student_information_1/payment/models/item.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';
import 'package:student_information_1/payment/ui/screens/card_entry_screen.dart';
import 'package:student_information_1/payment/ui/screens/payment_select_screen.dart';
import 'package:student_information_1/payment/ui/screens/purchase_complete_screen.dart';

export 'package:student_information_1/payment/providers.dart'
    show paymentNavigatorKey, paymentMessengerKey;

/// C4 決済フローの名前付きルートを解決する。C4 以外の名前は null。
/// 教材一覧・詳細は C1 の MarketSearchScreen / MarketDetailScreen が担うため、
/// ここでは支払フロー（W15 以降）の名前付きルートのみを解決する。
Route<dynamic>? onGeneratePaymentRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.paymentSelect:
      final item = settings.arguments;
      if (item is! Item) return null;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => PaymentSelectScreen(item: item),
      );
    case AppRoutes.cardEntry:
      final args = settings.arguments;
      if (args is! CardEntryArgs) return null;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CardEntryScreen(args: args),
      );
    case AppRoutes.purchaseComplete:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => PurchaseCompleteScreen(
          listingId: settings.arguments as String?,
        ),
      );
  }
  return null;
}
