# Claude Code 実装指示書 — 有償カード決済（clientSecret 受領後の実決済）（C4 取引・決済処理部）

<!-- 保存先: docs/instructions/20260710_card_payment.md -->
<!-- 2026-07-10 の実装前調査で確定したスコープ・SDK方式に基づく。実装前に「⚠️ 要確認」を潰すこと -->

## あなた（Claude Code）へのタスク

このリポジトリ（Flutter + Firebase、Flutter パッケージ名 `student_information_1`）の
`feature/payment` ブランチに、**有償フローの実カード決済**（`createPaymentIntent` で受領済みの
`clientSecret` を使い、カード入力 → Stripe で決済実行 → 購入完了画面へ）を実装してください。

サーバ側（`createPaymentIntent` / `handleStripeWebhook` / `fulfillOrder`）は**実装済み・テスト済み**で、
今回は**一切変更しません**。今回の中心は「`clientSecret` 受領後のクライアント側決済実行」と
「Stripe をローカルで実接続するための設定（＝木幡さんの手作業手順）」です。

**このドキュメントはステップ0〜4に分かれています。1ステップずつ実装し、各ステップの検証が
通ってから次へ進んでください。** 全ステップ完了までコミット・push はしません。
テストカードによる最終E2E確認は、木幡さんが手作業（Stripeアカウント・キー・CLI）を
済ませた後に行います（末尾「木幡さん向け手順」）。

---

## 確定したスコープ（変更不可）

| # | 項目 | 決定 |
|---|---|---|
| 1 | SDK方式 | **①`flutter_stripe` + `flutter_stripe_web`（Dart完結）**。Webで詰まったら②Stripe.js直挿しへ退避（退避条件は Step1 に明記） |
| 2 | スコープ | ローカル（エミュレータ + Stripe CLI）でテストカード決済が通り、**購入完了画面到達 & item が sold になる**まで。 |
| 3 | 今回スコープ外 | 本番デプロイ・ダッシュボードでの Webhook 登録・返金API・管理者アラート（班相談/別タスク） |
| 4 | item を sold にするのは誰か | **Webhook（`handleStripeWebhook`→`fulfillOrder`）**。クライアントの `confirmPayment` 成功は「決済OKの合図」で、Firestore の `sold` 確定は非同期。クライアントは確定を待たずに完了画面へ進む |
| 5 | publishable key の渡し方 | **`--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`**。コード直書き・pubspec埋め込みは禁止 |
| 6 | 秘密鍵の扱い | `sk_test_`/`whsec_` は**リポジトリ・コミットに絶対入れない**。ローカルは `functions/.secret.local`（Step0 で gitignore） |

---

## 【最重要】全ステップ共通の厳守事項

- ❌ **サーバ決済コアを一切変更しない**：`functions/src/{createPaymentIntent,webhook,fulfill,freeTransfer,index,chatRoom}.ts`
  と `functions/src/__tests__/*` は今回**触らない**（`git diff --stat` で functions に差分ゼロを示す）。
- ❌ **決済フローの配線を壊さない**：`payment_flow_navigation.dart` の `confirmAndPay` のロジック
  （在庫ロック→0円分岐→createPaymentIntent→goToCardEntry）は**変更しない**。今回足すのは
  `goToCardEntry` に **`listingId` を1つ増やす追加配線のみ**（Step3-0）。
- ❌ **秘密情報をコード/コミットに入れない**：リポジトリに入れてよいのは publishable key（`pk_test_`）のみ、
  それも `--dart-define` 経由で**コードにも書かない**。`sk_test_`/`whsec_` は `.secret.local`（gitignore 済み）だけ。
- ⚠️ **他機能（スポット等）のビルドを壊さない**：`STRIPE_PUBLISHABLE_KEY` 未指定でもアプリは起動できること
  （Stripe 初期化を空キーガードで囲む。Step2）。スポット担当が `--dart-define` なしで `flutter run` しても動く状態を保つ。
- Flutter は **`dart analyze` で新たな警告を出さない**（授業のコーディング規約要件）。
  既存ファイルに元からある警告はスコープ外（新規に増やさなければよい）。
- コミット・push は行わない。各ステップの差分と検証結果を報告して確認を待つ。

---

## 設計の前提（既存コードから抽出した事実）

- **有償フローは決済実行の一歩手前まで配線済み**：
  `PaymentSelectScreen.確定` → `PurchaseFlowCoordinator.confirmAndPay`
  （`payment_flow_navigation.dart:55`）→ `M3.createPaymentIntent`（Callable）で
  `{clientSecret, paymentIntentId}` を受領 → `navigator.goToCardEntry(clientSecret, paymentIntentId, amount)`
  （`:98`）→ `CardEntryScreen(args)`。**この `CardEntryScreen` が空（プレースホルダ）**。
- **`CardEntryScreen` の現状**（`lib/payment/ui/screens/card_entry_screen.dart`）：
  `StatelessWidget`。金額・決済ID・「準備中です」の固定文言・「一覧へ戻る」ボタンのみ。
  ファイル冒頭コメントに「実装時は `CardEntryArgs.clientSecret` を Stripe SDK に渡す」と明記。
- **`CardEntryArgs`**（`flutter_payment_navigator.dart:22`）は現状 `clientSecret` / `paymentIntentId` / `amount`
  のみ。**`listingId` を持たない** → 決済成功後に `goToPurchaseComplete(listingId, transactionId)` を
  呼ぶには `listingId` を足す必要がある（Step3-0）。
- **完了画面への遷移メソッドは既存**：`goToPurchaseComplete({required String listingId, String? transactionId})`
  （`flutter_payment_navigator.dart:75`）。**有償フローの `transactionId` は `paymentIntentId`**
  （webhook が `transactions/{paymentIntentId}` を作り、チャット部屋 ID もこれに一致する設計）。
- **DI パターン**：画面は `lib/payment/providers.dart` のプロバイダだけを参照し、テストは
  `ProviderScope(overrides: [...])` で Fake に差し替える（`test/payment/payment_screens_test.dart` 参照）。
  Fake は具象/interface を `implements` する。
- **既存 Flutter テストがカード入力画面まで到達する**：`payment_screens_test.dart:196`
  「W15(有償): 確定でカード入力画面へ」が実 `onGeneratePaymentRoute` 経由で `CardEntryScreen` を描画し、
  `お支払い金額: ¥1500` を assert している。→ 新実装でも**この金額表示テキストは残す**こと。かつ、
  新 `CardEntryScreen` が Stripe のカード入力ウィジェットを描画するため、**この既存テストの `buildTestApp` に
  `cardPaymentClientProvider` の Fake override を足す**必要がある（Step4-0。足さないと flutter test で
  プラットフォームビューが描画できず落ちる）。
- **`PaymentNavigator` の具象は `FlutterPaymentNavigator` 1つだけ**（他に実装者がいないことを
  `grep -rn "implements PaymentNavigator" lib test` で確認してから interface を変更すること）。
- **サーバ側の環境変数配線は完了済み**：`functions/src/index.ts` が `STRIPE_SECRET_KEY` /
  `STRIPE_WEBHOOK_SECRET` を `defineSecret` で参照。値の注入（`.secret.local`）だけが未実施。
- **Functions のリージョンは `asia-northeast1`**、Firebase プロジェクト ID は `campus-info-share`
  （`.firebaserc`）。→ ローカル webhook 転送先 URL は
  `localhost:5001/campus-info-share/asia-northeast1/handleStripeWebhook`。

---

## ディレクトリ構成（変更/作成するファイル）

```
.gitignore                                          # 【変更・追記のみ】functions/.secret.local を追加（Step0）

pubspec.yaml                                         # 【変更・追記のみ】flutter_stripe / flutter_stripe_web（Step1）
web/index.html                                       # 【変更・要確認】Stripe.js script が必要なら追記（Step1）
lib/main.dart                                        # 【変更】publishable key で Stripe 初期化（空キーガード付き）（Step2）

lib/payment/services/card_payment_client.dart        # 【新規】CardPaymentClient interface（SDK非依存の抽象）
lib/payment/services/stripe_card_payment_client.dart # 【新規】上記の Stripe 具象（flutter_stripe を import する唯一の実装ファイル）
lib/payment/providers.dart                           # 【変更・追記のみ】cardPaymentClientProvider を1つ追加
lib/payment/ui/screens/card_entry_screen.dart        # 【全面実装】カード入力UI + confirmPayment + 遷移/エラー/多重防止

lib/payment/ui/flutter_payment_navigator.dart        # 【変更】CardEntryArgs に listingId 追加 + goToCardEntry 引数追加（Step3-0）
lib/payment/ui/payment_flow_navigation.dart          # 【変更・1箇所】PaymentNavigator.goToCardEntry の interface と :98 の呼び出しに listingId を渡す

test/payment/payment_screens_test.dart               # 【変更・追記のみ】buildTestApp に cardPaymentClientProvider の Fake override を追加（Step4-0）
test/payment/card_entry_test.dart                    # 【新規】card_entry の widget テスト（Stripe を Fake 化）
```

> `functions/` 配下・`firestore.rules`・スポット機能ファイルは**変更しない**。

---

# ステップ0（最重要・最初にやる）: `.secret.local` を gitignore に追加

## 目的
以降のどの作業でも `sk_test_` / `whsec_` が**絶対にコミットされない**状態を、最初に作る。

## 0-1. `.gitignore`（追記のみ）
既存の「Environment variable files」ブロックの近くに、以下を追記する（既存行は変更しない）:

```gitignore
# Firebase Functions local secrets (Stripe sk_ / whsec_) — 絶対にコミットしない
functions/.secret.local
functions/.secret*.local
```

> 現状 `.gitignore` は `.env` / `.env.*` を無視するが、Firebase Functions がローカルシークレットに使う
> `functions/.secret.local` は**カバーされていない**。ここを先に塞ぐ。

## 0-2. ステップ0の検証
```bash
# .secret.local を作っても git が無視することを確認（ダミーで確認し、確認後は消す）
printf 'STRIPE_SECRET_KEY=sk_test_DUMMY\n' > functions/.secret.local
git check-ignore functions/.secret.local        # → functions/.secret.local と出れば無視されている
git status --porcelain functions/.secret.local  # → 何も出なければOK（追跡対象外）
rm functions/.secret.local                       # ダミーを消す
```
- **合格条件**：`git check-ignore` が当該パスを出力し、`git status` に現れないこと。

---

# ステップ1: Stripe パッケージ追加（pubspec）

## 目的
Flutter Web で Stripe 決済を実行できる SDK を入れる（方式①）。

## 1-1. `pubspec.yaml`（`dependencies:` に追記のみ）
既存の依存の並びに合わせて追記する（バージョンは `flutter pub get` が解決する最新安定を使い、
入れた実バージョンを報告する。⚠️ 下記 API はバージョン差があるため、確定後に実 API を確認すること）:

```yaml
  # Stripe 決済（有償フローのカード決済。Web は flutter_stripe_web が Stripe.js を橋渡し）
  flutter_stripe: ^11.0.0        # ⚠️ 要確認: 解決される最新安定に合わせる
  flutter_stripe_web: ^6.0.0     # ⚠️ 要確認: flutter_stripe と互換のあるバージョン
```

```bash
flutter pub get
```

## 1-2. `web/index.html`（要確認・必要なら追記）
`flutter_stripe_web` は Stripe.js を利用する。**多くのバージョンで Stripe.js は自動注入されるが、
バージョンによっては `web/index.html` の `<head>` に手動追加が必要**。パッケージの README/CHANGELOG を確認し、
必要な場合のみ以下を Google Maps の script 付近に追記する:

```html
  <script src="https://js.stripe.com/v3/"></script>
```

> ⚠️ 要確認：不要なのに二重ロードすると警告が出る。**パッケージのドキュメントで「自動注入」なら追記しない**。

## 1-3. 依存競合・ビルドエラー時の対処と、方式②への退避条件
- **依存解決に失敗（version solving failed）**：`flutter_stripe` と `flutter_stripe_web` のバージョン整合、
  および既存依存（`firebase_*`, `google_maps_flutter` 等）との競合を確認。必要なら両者のバージョンを
  互換ペアに調整する。**他パッケージのバージョンは勝手に上げない**（競合が他機能に波及するため。
  解決できない場合は報告して止まる）。
- **`flutter build web` / `flutter run -d chrome` が Stripe 起因で失敗**：エラーを記録して報告。
- **方式②（Stripe.js 直挿し）への退避条件**：以下のいずれかに該当し、上記で解決できないとき。
  この判断は**木幡さんに報告して指示を仰ぐ**（勝手に②へ切り替えない）:
  1. `flutter_stripe_web` が現行 Flutter/依存と互換のバージョンを解決できない
  2. Web で `CardField`/`CardFormField` が描画できない・`confirmPayment` が Web で機能しない
  3. Web ビルドが Stripe 起因で恒常的に壊れる

## 1-4. ステップ1の検証
```bash
flutter pub get
dart analyze                      # 追加起因の新規警告ゼロ
flutter build web                 # Web ビルドが通る（Stripe 起因のエラーが無い）
```
- **合格条件**：`flutter pub get` 成功、`dart analyze` 新規警告ゼロ、`flutter build web` 成功。
- 入れた実バージョン（flutter_stripe / flutter_stripe_web）を報告する。

---

# ステップ2: 起動時に publishable key で Stripe 初期化

## 目的
`pk_test_` をコードに書かず、`--dart-define` から受けて Stripe を初期化する。未指定でもアプリは起動する。

## 2-1. `lib/main.dart`（変更）
`Firebase.initializeApp` の後、`runApp` の前に、**空キーガード付き**で初期化を足す。

方針（擬似コード。実 API はインストールした flutter_stripe のバージョンに合わせる。⚠️ 要確認）:
```dart
// import 'package:flutter_stripe/flutter_stripe.dart';

const stripePublishableKey =
    String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');

// ... Firebase.initializeApp の後 ...
if (stripePublishableKey.isNotEmpty) {
  Stripe.publishableKey = stripePublishableKey;
  // 一部バージョン/プラットフォームで設定反映に必要。要確認。
  await Stripe.instance.applySettings();
}
```

- **空キーガード必須**：`STRIPE_PUBLISHABLE_KEY` 未指定（スポット担当が `--dart-define` 無しで起動する等）でも
  クラッシュせず起動し、決済フローに入ったときだけカード決済が使えない状態にする。
- **key をコードに書かない**：`defaultValue` はあくまで空文字。実キーは実行時に `--dart-define` で渡す。

## 2-2. ステップ2の検証
```bash
dart analyze lib/main.dart
flutter build web                                              # キー無しでもビルド成功
flutter build web --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_DUMMY   # キー有りでもビルド成功
```
- **合格条件**：両方のビルドが成功。`dart analyze` 新規警告ゼロ。実 pk は使わずダミーで確認。

---

# ステップ3: `card_entry_screen` の実装（カード入力 + 決済実行 + 遷移）

## 目的
`clientSecret` を Stripe に渡してカード決済を実行し、成功で完了画面、失敗でエラー表示。
多重送信を防止し、処理中はローディングを出す。**item の sold 化はしない（Webhook の責務）**。

## 3-0. 追加配線: `CardEntryArgs` に `listingId` を持たせる（先にやる）
完了画面遷移 `goToPurchaseComplete(listingId, transactionId)` のために `listingId` を運ぶ。

`grep -rn "implements PaymentNavigator" lib test` で具象が `FlutterPaymentNavigator` のみであることを
確認してから、以下を**追加のみ**で変更する:

1. `lib/payment/ui/flutter_payment_navigator.dart`
   - `CardEntryArgs` に `final String listingId;` を追加（コンストラクタ `required this.listingId`）。
   - `goToCardEntry(...)` に `required String listingId` を追加し、`CardEntryArgs` に渡す。
2. `lib/payment/ui/payment_flow_navigation.dart`
   - `abstract`/`interface` の `PaymentNavigator.goToCardEntry(...)` シグネチャに `required String listingId` を追加。
   - `:98` の呼び出し `_navigator.goToCardEntry(...)` に `listingId: listingId`（この行のスコープに `listingId` あり）を追加。

> これは決済ロジックの変更ではなく引数の追加。`confirmAndPay` の分岐・戻り値（`PurchaseSession`）は変えない。

## 3-1. `lib/payment/services/card_payment_client.dart`（新規・SDK非依存の抽象）
Stripe をテストで Fake 化できるよう、**カード入力ウィジェットと決済実行の両方**を1つの interface で抱える。
これはコードベースの設計思想（core は SDK を import せず、edge だけが SDK を持つ）に合わせるため。

```dart
/// カード決済のクライアント抽象。Stripe SDK 依存を1点に閉じ込め、テストで Fake 化する。
abstract class CardPaymentClient {
  /// カード情報入力ウィジェット（実装: Stripe のカードフィールド／Fake: ダミー）。
  Widget buildCardInput();

  /// clientSecret でカード決済を確定する。
  /// 成功で正常終了、失敗は C4Exception を投げる（画面はこれを捕まえて showError）。
  Future<void> confirmPayment({required String clientSecret});
}
```
（`C4Exception` は既存 `transaction_models.dart` のものを使う。`Widget` のため `flutter/widgets.dart` を import。）

## 3-2. `lib/payment/services/stripe_card_payment_client.dart`（新規・flutter_stripe を import する唯一の実装）
```dart
// import 'package:flutter_stripe/flutter_stripe.dart';  // ここだけが SDK を import
class StripeCardPaymentClient implements CardPaymentClient { ... }
```
- `buildCardInput()`：Stripe のカード入力ウィジェット（`CardFormField` もしくは `CardField`）を返す。
  ⚠️ 要確認：採用ウィジェットと、それが `confirmPayment` にカード情報を渡す方法はバージョン依存。
- `confirmPayment({required String clientSecret})`：擬似コード（⚠️ 実 API はバージョンで確認）:
  ```dart
  try {
    await Stripe.instance.confirmPayment(
      paymentIntentClientSecret: clientSecret,
      data: const PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(),
      ),
    );
  } on StripeException catch (e) {
    throw C4Exception(402, e.error.localizedMessage ?? 'カード決済に失敗しました。');
  } catch (e) {
    throw C4Exception(502, '決済処理に失敗しました。($e)');
  }
  ```
  > `confirmPayment` のパラメータ名（`paymentIntentClientSecret` 等）はバージョンで変わる。
  > インストールした版の型定義で確認してから確定すること。

## 3-3. `lib/payment/providers.dart`（追記のみ）
```dart
// import 追加: card_payment_client.dart / stripe_card_payment_client.dart
/// カード決済クライアント（テストで Fake に差し替え可能）。
final cardPaymentClientProvider =
    Provider<CardPaymentClient>((ref) => StripeCardPaymentClient());
```

## 3-4. `lib/payment/ui/screens/card_entry_screen.dart`（全面実装）
`StatelessWidget` → `ConsumerStatefulWidget` に変更（Riverpod でクライアント/ナビゲータを read するため）。

- **表示**：
  - `お支払い金額: ¥${args.amount}`（**この文言は既存テスト互換のため必ず残す**）。
  - `ref.read(cardPaymentClientProvider).buildCardInput()` でカード入力欄を表示。
  - 「支払う」ボタン（`FilledButton` 等）。
- **押下時**（`_onPay`）:
  1. `_processing == true` なら即 return（多重送信防止）。
  2. `setState(() => _processing = true)`。ボタンを無効化しローディング（`CircularProgressIndicator`）表示。
  3. `try { await ref.read(cardPaymentClientProvider).confirmPayment(clientSecret: args.clientSecret); }`
  4. **成功**：`ref.read(paymentNavigatorProvider).goToPurchaseComplete(listingId: args.listingId, transactionId: args.paymentIntentId);`
     - ⚠️ ここで item を sold にしない・fulfill を呼ばない。**確定は Webhook が非同期に行う**（決定#4）。
       完了画面には「決済を受け付けました。反映まで少し時間がかかる場合があります」程度の注記を出してよい
       （出す場合は `purchase_complete_screen` ではなく本画面遷移前後の文言で最小対応。既存完了画面は変更しない）。
  5. **失敗（`on C4Exception`）**：`ref.read(paymentNavigatorProvider).showError(code: e.code, message: e.message);`
     `setState(() => _processing = false)` でボタンを再活性（同じ画面で再試行可能）。
  6. `if (!mounted) return;` を非同期後に必ず挟む（既存画面の作法に合わせる）。
- **`clientSecret` は画面に生表示しない**（`paymentIntentId` の表示は任意。ログにも secret を出さない）。

> なぜ Webhook 確定を待たないか：`fulfillOrder` は Stripe→Webhook 経由で非同期に走る。クライアントは
> `confirmPayment` 成功（＝オーソリ完了）を合図に完了画面へ進み、Firestore の `sold`／`transactions.paid` は
> サーバが確定する。二重確定を避けるため、クライアントからは fulfill 系を呼ばない。

## 3-5. ステップ3の検証
```bash
flutter pub get
dart analyze lib/payment/ lib/main.dart
flutter build web --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_DUMMY
```
- **合格条件**：`dart analyze` 新規警告ゼロ、Web ビルド成功。テストは Step4 でまとめて実施。

---

# ステップ4: テスト（Stripe を Fake 化）と全体検証

## 目的
Stripe SDK を Fake 化し、`confirmPayment` 成功→完了画面遷移、失敗→エラー表示、多重送信防止を検証。
既存の Flutter テストを壊さない。

## 4-0. `test/payment/payment_screens_test.dart`（追記のみ・既存テスト非破壊）
新 `CardEntryScreen` は `cardPaymentClientProvider` を read するため、**`buildTestApp` の overrides に
Fake を1つ足す**（足さないと既存の「W15(有償)」テストがカードウィジェット描画で落ちる）。

- テスト用 `FakeCardPaymentClient implements CardPaymentClient` を定義：
  - `buildCardInput()` は描画可能なダミー（例 `SizedBox.shrink()` か `Text('card')`）を返す。
  - `confirmPayment(...)` は既定で成功（何もしない）。呼び出し回数を記録し、失敗を注入できるようにする。
- `buildTestApp` の `overrides` に `cardPaymentClientProvider.overrideWithValue(FakeCardPaymentClient())` を追加。
- 既存 assert（`お支払い金額: ¥1500` 等）はそのまま通ること（金額表示を残したので互換）。

## 4-1. `test/payment/card_entry_test.dart`（新規）
`payment_screens_test.dart` の Fake/override パターンを踏襲。ナビゲーション検証のため、
**記録用 `FakePaymentNavigator implements PaymentNavigator`** を定義し
`paymentNavigatorProvider` を override（`goToPurchaseComplete`/`showError` の呼び出しを記録）。
`CardEntryScreen` は `CardEntryArgs`（`listingId`/`clientSecret`/`paymentIntentId`/`amount`）を与えて直接描画する。

受入テストケース:

| # | 条件 | 期待 |
|---|---|---|
| 1 | 画面描画 | 金額表示・カード入力（ダミー）・「支払う」ボタンが出る |
| 2 | 支払う→ confirmPayment 成功 | `goToPurchaseComplete(listingId, transactionId=paymentIntentId)` が1回呼ばれる |
| 3 | 支払う→ FakeCardPaymentClient が C4Exception を投げる | `showError` が呼ばれ、画面は遷移せず、ボタンが再活性する |
| 4 | 処理中に連打 | `confirmPayment` は1回だけ呼ばれる（多重送信防止） |

> 非同期後の `pumpAndSettle()`、`mounted` チェックに注意。ローディング表示中はボタンが disabled であることも確認するとよい。

## 4-2. ステップ4の検証（全体）
```bash
flutter pub get
dart analyze                       # 全体で新規警告ゼロ
flutter test test/payment/         # 既存 payment テスト + 新規 card_entry テストが pass
git diff --stat functions/         # functions に差分ゼロであることを示す
```
- **合格条件**：
  - `dart analyze` 新規警告ゼロ。
  - `flutter test test/payment/` が**既存テスト（従来 pass 件数を維持）+ 新規 card_entry テスト**すべて pass。
  - `functions/` と `firestore.rules` に差分ゼロ。

---

## 全体の受入条件チェックリスト

- [ ] `.gitignore` に `functions/.secret.local` を追加、`git check-ignore` で無視を確認（Step0）
- [ ] `pubspec.yaml` に flutter_stripe / flutter_stripe_web を追加（実バージョンを報告）
- [ ] `lib/main.dart` は **空キーガード付き**で Stripe 初期化（キー未指定でも起動する）
- [ ] publishable key は `--dart-define` 経由のみ。**コード・pubspec・コミットに実キーが無い**
- [ ] flutter_stripe を import するのは `main.dart` と `stripe_card_payment_client.dart` **だけ**
- [ ] `CardEntryScreen` は `confirmPayment` 成功で `goToPurchaseComplete`、失敗で `showError`、多重送信防止・ローディングあり
- [ ] **クライアントから fulfill/sold 化を呼んでいない**（sold は Webhook の責務。決定#4）
- [ ] `CardEntryArgs`/`goToCardEntry`/`PaymentNavigator` への変更は **listingId 追加のみ**（ロジック不変）
- [ ] `dart analyze` 新規警告ゼロ、`flutter build web`（キー有無両方）成功、`flutter test test/payment/` 全 pass
- [ ] `functions/` と `firestore.rules` に差分ゼロ（`git diff --stat`）
- [ ] コミット・push をしていない（差分のみ報告）

## 実装完了時に報告すること

- 各ステップの検証コマンドの**実際の出力**（テスト pass 件数を明示）
- 追加した flutter_stripe / flutter_stripe_web の実バージョン
- `git diff --stat`（`functions/`・`firestore.rules` に差分が無いこと）
- `--dart-define` 無しでアプリが起動する（他機能を壊していない）ことの確認結果
- 方式②（Stripe.js）への退避が必要になった場合はその理由（Step1-3 の該当条件）

---

# 【木幡さん向け手順】手作業（Claude ではできない・実装後に木幡さんが実施）

> 上記コード実装が完了した後、テストカードによる E2E 確認をするための手順。**本番デプロイは不要**
> （ローカルのエミュレータ + Stripe CLI で完結する）。

### 準備（一度だけ）
1. **Stripe アカウント作成**（テストモードでよい・無料）。
2. ダッシュボード（テストモード）で **publishable key `pk_test_...`** と **secret key `sk_test_...`** を控える。
3. **Stripe CLI 導入** → `stripe login`。

### ローカル E2E 確認（毎回）
4. **サーバのローカルシークレット**：`functions/.secret.local` を作成（Step0 で gitignore 済み）:
   ```
   STRIPE_SECRET_KEY=sk_test_あなたの鍵
   STRIPE_WEBHOOK_SECRET=（次の 6 で得る whsec_）
   ```
5. **エミュレータ起動**（端末1）:
   ```bash
   cd functions && npm install && npm run serve
   ```
6. **Webhook をローカルへ転送**（端末2）。表示される `whsec_...` を上の `.secret.local` に設定して 5 を再起動:
   ```bash
   stripe listen --forward-to localhost:5001/campus-info-share/asia-northeast1/handleStripeWebhook
   ```
7. **アプリ起動**（端末3。publishable key を渡す）:
   ```bash
   flutter run -d chrome --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_あなたの鍵
   ```
8. 有償の教材を購入 → カード入力で **テストカード `4242 4242 4242 4242` / 任意の将来の有効期限 / 任意の CVC** を入力 → 支払う。
9. **確認する結果**：
   - 購入完了画面へ遷移する。
   - 端末2の `stripe listen` に `payment_intent.succeeded` が届き、Webhook が 200 を返す。
   - Firestore エミュレータ UI で該当 `items/{listingId}.status` が **`sold`**、`transactions/{paymentIntentId}.status` が **`paid`** になる。

### スコープ外（今回はやらない・別途チーム相談）
- 本番デプロイ（`firebase deploy --only functions`）とダッシュボードでの Webhook エンドポイント登録。
- 返金 API（金額不一致時の `refundNeeded`）と管理者アラート。

> ⚠️ `sk_test_` / `whsec_` は `functions/.secret.local` だけに置き、**チャットに貼らない・コミットしない**。
> `pk_test_` はクライアント公開前提の鍵なので `--dart-define` で渡してよい（コードには書かない）。
