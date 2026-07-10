/// 学内情報共有システム — C4 取引・決済処理部
/// Riverpod プロバイダ定義（C4 の依存ツリーをここで一元的に組み立てる）
///
/// 画面はこのファイルのプロバイダだけを参照する。テストでは
/// ProviderScope(overrides: [...]) で Fake に差し替える。
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:student_information_1/C3/market_manager.dart';
import 'package:student_information_1/payment/m2_purchase_control.dart';
import 'package:student_information_1/payment/m3_gateway_integration.dart';
import 'package:student_information_1/payment/services/c5_interfaces.dart';
import 'package:student_information_1/payment/services/card_payment_client.dart';
import 'package:student_information_1/payment/services/stripe_card_payment_client.dart';
import 'package:student_information_1/payment/services/callable_free_transfer_client.dart';
import 'package:student_information_1/payment/services/callable_payment_gateway_client.dart';
import 'package:student_information_1/payment/services/firestore_item_repository.dart';
import 'package:student_information_1/payment/services/in_memory_pending_item_store.dart';
import 'package:student_information_1/payment/services/item_catalog_repository.dart';
import 'package:student_information_1/payment/ui/flutter_payment_navigator.dart';
import 'package:student_information_1/payment/ui/payment_flow_navigation.dart';

/// MaterialApp に登録する GlobalKey（main.dart から参照）。
/// FlutterPaymentNavigator が BuildContext を跨いだ遷移に使う。
final GlobalKey<NavigatorState> paymentNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> paymentMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// サインイン中ユーザーの uid（未ログインなら null）。
/// 画面が FirebaseAuth を直接触らないようにする（テストで差し替え可能）。
final currentUidProvider = Provider<String?>(
  (ref) => FirebaseAuth.instance.currentUser?.uid,
);

/// 表示用: 教材カタログ（read 専用）。
final itemCatalogRepositoryProvider = Provider<ItemCatalogRepository>(
  (ref) => ItemCatalogRepository(),
);

/// 出品取消などの教材書き込み操作（テストで Fake に差し替え可能にする）。
final marketManagerProvider = Provider<MarketManager>((ref) => MarketManager());

/// 取引用: 在庫ロック/解除（C5 ItemRepository 具象）。
final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => FirestoreItemRepository(),
);

final paymentGatewayClientProvider = Provider<PaymentGatewayClient>(
  (ref) => CallablePaymentGatewayClient(),
);

/// カード決済クライアント（clientSecret 受領後の決済実行）。
/// テストでは Fake に差し替える。実装は flutter_stripe を閉じ込めた具象。
final cardPaymentClientProvider = Provider<CardPaymentClient>(
  (ref) => const StripeCardPaymentClient(),
);

final freeTransferClientProvider = Provider<FreeTransferClient>(
  (ref) => CallableFreeTransferClient(),
);

/// 外部変数 c_pending_item_id（アプリ内で1個だけ保持）。
final pendingItemStoreProvider = Provider<PendingItemStore>(
  (ref) => InMemoryPendingItemStore(),
);

final paymentNavigatorProvider = Provider<PaymentNavigator>(
  (ref) => FlutterPaymentNavigator(
    navigatorKey: paymentNavigatorKey,
    messengerKey: paymentMessengerKey,
  ),
);

/// 購入フロー コーディネータ（W15「確定」押下時の入口）。
final purchaseFlowCoordinatorProvider = Provider<PurchaseFlowCoordinator>(
  (ref) {
    final itemRepository = ref.watch(itemRepositoryProvider);
    return PurchaseFlowCoordinator(
      m2: PurchaseControlModule(itemRepository),
      m3: GatewayIntegrationModule(
        paymentGateway: ref.watch(paymentGatewayClientProvider),
        itemRepository: itemRepository,
      ),
      freeTransfer: ref.watch(freeTransferClientProvider),
      itemRepository: itemRepository,
      navigator: ref.watch(paymentNavigatorProvider),
      pendingStore: ref.watch(pendingItemStoreProvider),
    );
  },
);
