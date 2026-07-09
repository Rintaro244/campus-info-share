# Claude Code 実装指示書 — 出品取消（items delete）機能（C4 取引・決済処理部）

<!-- 保存先: docs/instructions/20260709_item_delete.md -->
<!-- 設計調査（2026-07-09）で確定した7決定事項に基づく。実装前に「⚠️ 要確認」を潰すこと -->

## あなた（Claude Code）へのタスク

このリポジトリ（Flutter + Firebase、Flutter パッケージ名 `student_information_1`）の
`feature/payment` ブランチに、**出品者が自分の出品した教材（items）を取り消せる機能**を実装してください。

削除は **出品者本人 かつ 販売中（on_sale）の item に限定**します。手続き中（pending）・
売却済（sold）は購入者保護のため削除不可です。

**このドキュメントはステップ1〜3に分かれています。1ステップずつ実装し、各ステップの検証が
通ってから次へ進んでください。** 全ステップ完了までコミット・push はしません。

---

## 確定した設計方針（7決定事項・変更不可）

| # | 項目 | 決定 |
|---|---|---|
| 1 | Rules 方式 | 案1：本人（`auth.uid == sellerId`）かつ `status == 'on_sale'` のみ delete 許可 |
| 2 | Storage 画像 | 段階導入。今回は item ドキュメント削除のみ。**画像は放置**（削除トリガーは後日別タスク） |
| 3 | UI 導線 | `market_detail_screen` に出品者向け「出品を取り消す」ボタンを新設。profile_screen の既存導線は活かさない |
| 4 | profile_screen 偽成功バグ | 今回のスコープに含めるが**最小対応**：`deleteProduct` の戻り値を見て「失敗なら失敗表示に分岐」だけ直す（dummy uid・status 欠落の完全修正は別タスク） |
| 5 | status 判定 | UI 側でもガード：**on_sale かつ本人のときだけ**取消ボタンを表示 |
| 6 | 削除後の一覧更新 | 詳細→一覧の再取得（Stream 化は別タスク） |
| 7 | storage.rules 整備 | 今回は画像を触らないため**不要・保留** |

---

## 【最重要】全ステップ共通の厳守事項

- ❌ **決済コアを壊さない**：`functions/src/{fulfill,freeTransfer,webhook,createPaymentIntent}.ts` は
  今回**一切変更しない**（本機能は functions を触らない）。
- ❌ **在庫ロック機構を壊さない**：`firestore.rules` の items の **create / update ルール
  （`isLock` / `isUnlock` / `priceSellerUnchanged`）は1行も変更しない**。今回変更するのは
  `allow delete` の1箇所だけ。
- ❌ **既存テストを壊さない**：
  - Rules テスト（`firestore-tests/rules.test.js`）の既存 items 17件・chats 14件。
    特に **既存 test⑨**（`BUYER が on_sale を delete → assertFails`）は、案1でも
    「BUYER は sellerId 不一致」で拒否されるため**そのまま pass する**（後述で確認）。
  - functions テスト30件・Flutter payment テスト21件。
- Flutter は **`dart analyze` で新たな警告を出さない**こと（授業のコーディング規約要件）。
  既存ファイルに元からある警告は今回のスコープ外（新規に増やさなければよい）。
- コミット・push は行わない。各ステップの差分と検証結果を報告して確認を待つ。

---

## 設計の前提（既存コードから抽出した事実）

- **現在の delete ルール**：`firestore.rules:28-29` は `allow delete: if false;`
  （「出品取消は別タスク」とコメント済み）。create（17-26行）/ update（32-59行）は独立。
- **削除ロジックは既存**：`MarketManager.deleteProduct(String docId, String? imageUrl)`
  （`lib/C3/market_manager.dart:115-133`）。
  - 消すコレクションは **`items`**（`collection('items')`）。旧 `products` は廃止済み。
  - 手順：`items/{docId}.delete()` → `imageUrl` があれば `refFromURL(imageUrl).delete()` を
    試行（失敗は握って無視）。**戻り値は bool**（全体 try/catch で失敗時 false）。
  - 今回 Storage は放置方針（決定#2）だが、**deleteProduct は既に画像削除を試みる実装**。
    今回はこの挙動を変えず、呼び出し側から画像 URL を渡すか否かで制御する。
    → ⚠️ 決定#2（画像放置）を厳密に守るなら、呼び出し時に **imageUrl に null を渡して
    画像削除を発火させない**のが安全（下記ステップ2で指定）。
- **詳細画面の下地が既にある**：`market_detail_screen.dart` は
  `currentUidProvider`（58行で使用）と `item.sellerId` / `item.status` を保持。
  購入ボタンの確認ダイアログ（`showDialog<bool>` → `Navigator.pop(context, bool)`、67-84行）が
  取消ボタンの雛形になる。
- **一覧の再取得は既に配線済み**：`market_search_screen.dart:82-92` は詳細画面から
  戻ると**無条件で `_fetchItems()` を呼ぶ**。→ 取消成功で詳細を `Navigator.pop` すれば
  一覧は自動更新される（決定#6は**一覧画面を変更せずに実現可能**）。
- **profile_screen の現状（バグ）**：`lib/C1/profile_screen.dart:177-200`。
  market 分岐（186行）で `deleteProduct` を **await するが戻り値を見ず**、その後（194-196行）
  常に「削除しました」SnackBar を表示。→ Rules で弾かれていた現状は「未削除なのに成功表示」。
- **DI パターン**：画面は `providers.dart` のプロバイダのみ参照し、テストは
  `ProviderScope(overrides: [...])` で Fake に差し替える（`test/payment/payment_screens_test.dart` 参照）。
  Fake は具象クラスを `implements` する（`FakeItemCatalogRepository implements ItemCatalogRepository`）。

---

## ディレクトリ構成（変更/作成するファイル）

```
firestore.rules                              # 【変更・1箇所のみ】items の allow delete を案1に差し替え
firestore-tests/
└── rules.test.js                            # 【変更・追記のみ】items delete の describe/テスト5件追加

lib/payment/providers.dart                   # 【変更・追記のみ】marketManagerProvider を1つ追加
lib/C1/market_detail_screen.dart             # 【変更】出品者向け「出品を取り消す」ボタン + 確認ダイアログ + 削除
lib/C1/profile_screen.dart                   # 【変更・最小】market 分岐で deleteProduct の戻り値を見て分岐

test/payment/
└── market_detail_delete_test.dart           # 【新規】取消ボタンの表示条件と削除動作の widget テスト
```

> `lib/C3/market_manager.dart` の `deleteProduct` は**変更しない**（既存実装をそのまま呼ぶ）。

---

# ステップ1: firestore.rules の items delete 許可（案1）+ Rules テスト

## 目的
出品者本人かつ on_sale の item のみ delete を許可する。create/update・ロック機構は無変更。

## 1-1. `firestore.rules`（1箇所のみ差し替え）

`items/{listingId}` ブロック内の以下（28-29行）を、

```
// 削除はクライアント不可（出品取消は別タスク・現時点スコープ外）
allow delete: if false;
```

案1に差し替える:

```
// 出品取消(delete): 出品者本人かつ販売中(on_sale)のみ。
// 手続き中(pending)・売却済(sold)は購入者保護のため削除不可。
allow delete: if request.auth != null
              && request.auth.uid == resource.data.sellerId
              && resource.data.status == 'on_sale';
```

**create / update / isLock / isUnlock / priceSellerUnchanged は一切触らない。**

## 1-2. `firestore-tests/rules.test.js`（追記のみ）

既存の `describe('items Security Rules', ...)` の中（末尾のテスト⑰の後）に delete テストを追加、
または新しい `describe('items delete Security Rules', ...)` を追加する。
既存テストは変更しない。seed 済みアイテムの `sellerId` は既存 `onSaleItem`/`pendingItem` が
`'seller1'` なので、**出品者として `authenticatedContext('seller1')` で叩く**こと。

受入テストケース:

| # | 前提（seed） | 操作 | 期待 |
|---|---|---|---|
| 1 | on_sale, sellerId=seller1 | seller1 が delete | **成功**（assertSucceeds） |
| 2 | on_sale, sellerId=seller1 | 他人（buyer1）が delete | 失敗（assertFails） |
| 3 | pending, sellerId=seller1 | seller1 が delete | 失敗（on_sale でない） |
| 4 | sold, sellerId=seller1 | seller1 が delete | 失敗（on_sale でない） |
| 5 | on_sale, sellerId=seller1 | 未ログインで delete | 失敗 |

> sold の seed が既存に無ければ `{ price:1000, status:'sold', sellerId:'seller1', buyerId:'buyer1' }` を
> ローカルで用意する（`withSecurityRulesDisabled` の `seed` ヘルパを使う）。

**既存 test⑨ の非破壊を確認**：test⑨ は `onSaleItem(sellerId:'seller1')` を `BUYER('buyer1')` が
delete → 案1でも「sellerId 不一致」で拒否 → **assertFails のまま pass**。ケース#2 と実質同じ検証だが、
test⑨ はそのまま残すこと（消さない）。

## 1-3. ステップ1の検証

```bash
cd firestore-tests && npm run test:emulator   # JDK 21 必須
```
- **合格条件**：既存 items 17 + chats 14 + 新規 delete 5 が全て pass（既存の pass 件数が減らないこと）。

---

# ステップ2: market_detail_screen に取消ボタン + 確認ダイアログ + 削除

## 目的
出品者本人が販売中の自分の教材を、詳細画面から確認ダイアログ付きで取り消せるようにする。

## 2-1. `lib/payment/providers.dart`（追記のみ）

`MarketManager` をテストで差し替え可能にするため、プロバイダを1つ追加する（既存プロバイダは無変更）:

```dart
// import 追加: package:student_information_1/C3/market_manager.dart
/// 出品取消などの教材書き込み操作（テストで Fake に差し替え可能にする）。
final marketManagerProvider = Provider<MarketManager>((ref) => MarketManager());
```

> なぜ provider 化するか：`MarketManager` は内部で `FirebaseFirestore.instance` を直接持つため、
> 画面から直接 `MarketManager()` を new すると widget テストで実 Firebase に触れてしまう。
> provider にすれば `ProviderScope(overrides:)` で Fake（`implements MarketManager`）に
> 差し替えられ、既存の DI パターンに揃う。

## 2-2. `lib/C1/market_detail_screen.dart`（変更）

`_buildContent(Item item)` の購入ボタン付近に、**出品者向け取消ボタン**を追加する。

- **表示条件（決定#5：UI 側でもガード）**：
  ```
  final uid = ref.read(currentUidProvider);
  final canCancel = uid != null && uid == item.sellerId && item.status == ItemStatus.onSale;
  ```
  `canCancel` が true のときだけ「出品を取り消す」ボタン（例：`OutlinedButton` 赤系 or `TextButton`）を出す。
  false のときは何も出さない（購入ボタンの表示ロジックはそのまま維持）。
- **押下時**：既存 `_onPurchasePressed` の確認ダイアログ（`showDialog<bool>`）を踏襲した
  取消用ダイアログを出す。文言例：「「{displayTitle}」の出品を取り消しますか？（この操作は取り消せません）」。
  キャンセル / 取り消す の2択。
- **確定時**：
  ```
  final ok = await ref.read(marketManagerProvider).deleteProduct(
    item.listingId,
    null, // 決定#2: 画像は放置。imageUrl を渡さず Storage 削除を発火させない
  );
  ```
  - `ok == true`：成功 SnackBar（例「出品を取り消しました」）→ `Navigator.pop(context)` で
    一覧へ戻る（一覧は `market_search_screen` が自動で `_fetchItems()` 再取得。決定#6）。
  - `ok == false`：失敗 SnackBar（例「出品の取消に失敗しました」）→ 画面は閉じない。
- **二重実行防止**：削除中フラグ（例 `_deleting`）でボタンを無効化し、`mounted` チェックを行う
  （既存画面の `if (!mounted) return;` 作法に合わせる）。

> ⚠️ `deleteProduct` の第2引数に画像 URL を渡すと Storage 削除が試行される。決定#2（画像放置）に
> 従い **null を渡す**こと。将来 C案3（削除トリガー）で画像はサーバ側が掃除する。

## 2-3. `test/payment/market_detail_delete_test.dart`（新規 widget テスト）

`test/payment/payment_screens_test.dart` の Fake 差し替え・`ProviderScope(overrides:)` パターンを踏襲。
- `FakeItemCatalogRepository implements ItemCatalogRepository`：`fetchItemById` で対象 Item を返す。
- `FakeMarketManager implements MarketManager`：`deleteProduct` の呼び出し引数を記録し、
  戻り値（true/false）をテストごとに設定可能にする。他メソッドは `noSuchMethod` か未使用でよい。
- override するプロバイダ：`currentUidProvider` / `itemCatalogRepositoryProvider` / `marketManagerProvider`。

受入テストケース:

| # | 条件 | 期待 |
|---|---|---|
| 1 | uid == sellerId かつ on_sale | 「出品を取り消す」ボタンが表示される |
| 2 | uid != sellerId（他人）on_sale | ボタンが表示されない |
| 3 | uid == sellerId だが status=pending / sold | ボタンが表示されない |
| 4 | ボタン→確認ダイアログ→「取り消す」→ deleteProduct(listingId, null) が呼ばれ、成功(true)で画面が pop する | 呼び出し引数・pop を検証 |
| 5 | deleteProduct が false | 失敗 SnackBar が出て、画面は pop しない | 

> ダイアログの「取り消す」ボタンのタップは、`showDialog` の overlay 描画のため
> `await tester.pumpAndSettle()` を挟むこと。

## 2-4. ステップ2の検証

```bash
flutter pub get
dart analyze lib/payment/providers.dart lib/C1/market_detail_screen.dart test/payment/market_detail_delete_test.dart
flutter test test/payment/
```
- **合格条件**：上記 analyze が **No issues**（変更/新規ファイルで新たな警告ゼロ）、
  payment テストが既存21 + 新規5 すべて pass。
- **依存パッケージは追加しない**（pubspec.yaml 無変更）。

---

# ステップ3: profile_screen の偽成功表示の最小修正

## 目的
Rules で delete が通るようになった後も、失敗時（例：他人/ pending/ sold で拒否）に
「削除しました」と誤表示しないようにする。**market 分岐のみ**の最小対応（決定#4）。

## 3-1. `lib/C1/profile_screen.dart`（最小変更）

対象は 177-200 行の削除ダイアログ確定ハンドラ。**market 分岐だけ**戻り値を見て分岐する。

- 変更方針（最小）：
  1. 削除結果を保持する変数を用意（例 `bool deleteOk = true;`）。
  2. market 分岐（186行）を `deleteOk = await MarketManager().deleteProduct(postId, imageUrl);` にする。
     - ⚠️ ここは既存の profile_screen の呼び出しで、決定#2 の「画像放置」対象外の別導線。
       既存の `imageUrl` 引数の受け渡しは**変えない**（このバグ修正は「戻り値で分岐」だけがスコープ）。
  3. ダイアログを閉じた後の SnackBar（194-196行）を `deleteOk` で分岐：
     - `deleteOk == true`：従来通り「削除しました」+ `_fetchUserData()`（再取得）。
     - `deleteOk == false`：「削除に失敗しました」等の失敗表示にし、成功メッセージは出さない。
- **circle / pastexam 分岐は触らない**（同種のバグがあっても今回スコープ外。決定#4）。
  `deleteOk` の初期値 true により、これらの既存挙動は変わらない。
- dummy uid（`dummy_user_123`）・status 欠落の完全修正は**やらない**（別タスク）。

> ⚠️ 要確認：profile_screen は他担当（C1）由来のファイル。最小修正に留め、既存の
> インデント・スタイルに合わせること。元からある `dart analyze` の info（avoid_print 等）は
> 今回**増やさない・（無関係なものは）直さない**。

## 3-2. ステップ3の検証

```bash
dart analyze lib/C1/profile_screen.dart
flutter test
```
- **合格条件**：
  - `profile_screen.dart` に **新たな警告を増やさない**（元からある指摘はスコープ外。
    変更行が新規警告を出さないことを確認）。
  - `flutter test` 全体で、**本 PR 起因の失敗が無い**こと。既存の circle 系テスト
    （`circle_ui_test` / `circle_manager_test`）の失敗は前 PR で確認済みの他担当の既存問題で、
    本タスクとは無関係（触っていないことを `git diff` で示す）。

---

## 全体の受入条件チェックリスト

- [ ] `firestore.rules` の変更は **items の `allow delete` 1箇所のみ**。create/update/isLock/isUnlock 無変更
- [ ] `cd firestore-tests && npm run test:emulator`：既存31 + 新規 delete 5 が pass、既存 test⑨ も pass
- [ ] `functions/` を一切変更していない（`git diff --stat` で確認）
- [ ] `flutter pub get` → `dart analyze`（変更/新規ファイル）で新規警告ゼロ → `flutter test test/payment/` が
      既存21 + 新規5 pass
- [ ] 取消ボタンは **on_sale かつ本人**のときだけ表示される（UI ガード。決定#5）
- [ ] `deleteProduct` は第2引数 null で呼び、Storage 画像を触らない（決定#2）
- [ ] 削除成功で詳細を pop → 一覧が自動再取得される（`market_search_screen` は無変更）
- [ ] profile_screen は market 分岐の戻り値分岐のみ（circle/pastexam・dummy uid は無変更）
- [ ] pubspec.yaml に差分が無い（依存追加なし）
- [ ] コミット・push をしていない（差分のみ）

## 実装完了時に報告すること

- 各ステップの検証コマンドの**実際の出力**（pass 件数を明示）
- `firestore.rules` の delete 差し替え diff（create/update に差分が無いこと）
- `functions/` に差分が無いことの `git diff --stat` 抜粋
- 取消ボタンの表示条件（本人×on_sale）が UI・Rules の二重で担保されていること
