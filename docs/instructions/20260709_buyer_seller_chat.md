# Claude Code 実装指示書 — 購入者⇄出品者チャット機能（C4 取引・決済処理部）

<!-- 保存先: docs/instructions/20260709_buyer_seller_chat.md -->
<!-- 設計調査（2026-07-09）で確定した8決定事項に基づく。実装前に「⚠️ 要確認」を潰すこと -->

## あなた（Claude Code）へのタスク

このリポジトリ（Flutter + Firebase、Flutter パッケージ名 `student_information_1`、
functions は TypeScript）の `feature/payment` ブランチに、**取引が成立した購入者と出品者が
やり取りできるチャット機能**を新規実装してください。

取引成立時に **Firestore トリガー（`onDocumentCreated`）でサーバ側がチャットルームを自動生成**し、
当事者2名だけが読み書きできるチャット画面を提供します。

**このドキュメントはステップ1〜4に分かれています。1ステップずつ実装し、各ステップの検証が
通ってから次へ進んでください。** 全ステップ完了までコミット・push はしません。

---

## 確定した設計方針（8決定事項・変更不可）

| # | 項目 | 決定 |
|---|---|---|
| 1 | 作成方式 | Firestore トリガー `onDocumentCreated`（決済コアは触らない） |
| 2 | トリガー種別 | `onDocumentCreated('transactions/{txId}')`。冪等性はルーム doc の存在チェックで担保 |
| 3 | roomId | `transactionId` をそのまま roomId に使う（`chats/{transactionId}`） |
| 4 | Rules 判定 | `chats/{roomId}` に `buyerId` / `sellerId` を個別フィールドで持ち、それで判定 |
| 5 | チャット寿命 | 残す（無期限。TTL・アーカイブは実装しない） |
| 6 | seller の取得 | トリガー内で `items/{listingId}.sellerId` を get して取得し、ルーム doc に保存 |
| 7 | UI スコープ | 完了画面の「出品者と連絡を取る」ボタンのみ（取引履歴からの入口は別タスク） |
| 8 | transactionId 受け渡し | navigator 改修を許容。初版は 0円フロー（`free_<listingId>`）で動けばよいが、将来の有償フロー（`pi.id`）でも動くよう汎用的に受け渡す |

---

## 【最重要】全ステップ共通の厳守事項

- ❌ **決済コアの4ファイルを一切変更しない**:
  `functions/src/fulfill.ts` / `functions/src/freeTransfer.ts` /
  `functions/src/webhook.ts` / `functions/src/createPaymentIntent.ts`
- ❌ **既存の functions テスト24件を変更しない・壊さない**:
  `functions/src/__tests__/` 配下の既存4ファイル（fulfill=5 / freeTransfer=9 /
  webhook=5 / createPaymentIntent=5）。新テストは**新規ファイル**として追加する。
- ❌ **チャットルーム作成の失敗が決済確定を巻き込んではならない**。決済（transaction=paid）は
  トリガー発火時点で既にコミット済み。トリガー内の例外はルーム作成を諦めるだけで、
  transaction は paid のまま残る。トリガーは決済のコアやテストに一切依存しない。
- `functions/src/index.ts` への変更は**新トリガーの export 追加（追記のみ）**に限る。
  既存の `createPaymentIntent` / `fulfillFreeTransfer` / `handleStripeWebhook` /
  `makeFulfillStore` の中身は触らない。
- Flutter 側は **`dart analyze` 警告ゼロ**が合格条件（授業のコーディング規約要件）。
- コミット・push は行わない。各ステップの差分と検証結果を報告して確認を待つ。

---

## 設計の前提（既存コードから抽出した事実）

- `transactions/{txId}` ドキュメントのフィールドは
  `listingId / buyerId / amount / status / eventId / createdAt / updatedAt`。
  **`sellerId` は持っていない**（`functions/src/types.ts` `TransactionDoc`）。
  → だから決定#6の通り、seller は `items/{listingId}.sellerId` から取得する。
- txId の形式は2通り: 有償=Stripe の `pi.id`（例 `pi_xxx`）、0円=`free_<listingId>`
  （`functions/src/freeTransfer.ts` `freeTransactionId()`）。**roomId はこの txId をそのまま使う**。
- fulfill / freeTransfer は transaction を **`set(..., {merge:true})` で `status:'paid'` にして作成**する。
  冪等再送時は「既に paid なら書き込まず no-op」なので、**paid の transaction 作成は取引ごとに1回**。
  → `onDocumentCreated` は取引ごとに1回発火する想定。
- `items/{listingId}` は `read: if true`（誰でも読める）。`sellerId` フィールドあり
  （`functions/src/index.ts` `mapItem`、`lib/payment/models/item.dart`）。
- 既存の唯一のリアルタイム表示パターンは `lib/past/past_exam_repository.dart`:
  `collection(...).orderBy('createdAt', ...).snapshots().map(...)` を Repository が返し、
  画面が `StreamBuilder` で購読。**チャットもこれを踏襲する**。
- 決済コアの設計思想 = 「SDK 非依存の純粋コア + 依存注入 + インメモリストアでテスト」
  （`functions/src/fulfill.ts` + `functions/src/__tests__/fulfill.test.ts`）。
  **新トリガーもこの型に合わせ、エミュレータ無しでコアをテストできるようにする。**

> ⚠️ 要確認（実装前に潰す）:
> - **A**: 0円フローで完了画面に遷移する際、クライアントが `listingId` を持っていることは
>   `PurchaseCompleteScreen` から確認済み。`transactionId = 'free_$listingId'` はクライアントで
>   導出できる。ただし**有償フローで完了画面へ来る導線が現状存在するか**、来る場合に `pi.id` を
>   どこで受け取るかは未トレース。ステップ4着手時に payment flow を追い、有償導線が無ければ
>   「初版は0円のみ、有償は導線実装時に txId を渡す」と割り切ってよい。
> - **B**: チャット画面で送信者を識別する `currentUid` は `FirebaseAuth.instance.currentUser?.uid`
>   から取る想定。決済フローが uid をどこかで保持していればそれを使ってよい。

---

## ディレクトリ構成（作成/変更するファイル）

```
functions/src/
├── chatRoom.ts                         # 【新規】チャットルーム生成の純粋コア（SDK非依存）
├── constants.ts                        # 【変更・追記のみ】COLLECTIONS.chats / CHAT_FIELDS 追加
├── index.ts                            # 【変更・追記のみ】onCreateChatRoom トリガー export 追加
└── __tests__/
    └── chatRoom.test.ts                # 【新規】chatRoom コアのユニットテスト（インメモリ）

firestore.rules                         # 【変更・追記のみ】chats / messages のルール追加
firestore-tests/
└── rules.test.js                       # 【変更・追記のみ】chats/messages の describe ブロック追加

lib/payment/
├── models/
│   ├── chat_room.dart                  # 【新規】ChatRoom モデル
│   └── chat_message.dart               # 【新規】ChatMessage モデル
├── services/
│   └── chat_repository.dart            # 【新規】メッセージ購読 Stream + 送信
└── ui/
    ├── screens/
    │   ├── chat_screen.dart            # 【新規】チャット画面（StreamBuilder + 入力欄）
    │   └── purchase_complete_screen.dart  # 【変更】「出品者と連絡を取る」ボタン追加
    ├── flutter_payment_navigator.dart  # 【変更】goToPurchaseComplete に transactionId 追加
    └── payment_flow_navigation.dart    # 【変更】ナビゲータ抽象IFに transactionId 追加

test/payment/
└── chat_screen_test.dart               # 【新規】チャット画面の widget テスト（Fake Repository）
```

---

# ステップ1: functions 側の新トリガー + テスト

## 目的
`transactions/{txId}` の新規作成を検知し、その取引の当事者2名のチャットルーム `chats/{txId}` を
自動生成する。決済コアには一切触れない。

## 1-1. `functions/src/constants.ts`（追記のみ）

`COLLECTIONS` に `chats: 'chats'` を追加。新たに以下を追加する（既存の値は変更しない）:

```ts
/** chats ドキュメントのフィールド名。 */
export const CHAT_FIELDS = {
  buyerId: 'buyerId',
  sellerId: 'sellerId',
  listingId: 'listingId',
  transactionId: 'transactionId',
  createdAt: 'createdAt',
  lastMessageAt: 'lastMessageAt',
} as const;

/** messages サブコレクション名。 */
export const CHAT_SUBCOLLECTIONS = { messages: 'messages' } as const;
```

## 1-2. `functions/src/chatRoom.ts`（新規・純粋コア）

決済コアと同じ「依存注入 + インメモリでテスト可能」な純粋関数として書く。
**Admin SDK を import しない**（依存は interface で受け取り、index.ts で注入）。

仕様:

- 入力: トリガーで作成された transaction のスナップショットから取り出した
  `{ transactionId: string, listingId?: string, buyerId?: string, status?: string }`。
- 依存 `ChatStore`（interface）:
  - `getItemSellerId(listingId): Promise<string | null>` … `items/{listingId}.sellerId` を返す
  - `getChatRoomExists(roomId): Promise<boolean>` … `chats/{roomId}` の存在チェック（冪等性）
  - `createChatRoom(roomId, data): Promise<void>` … ルーム doc を作成
  - `serverTimestamp(): unknown`
- ロジック（**例外を投げず、必ず結果オブジェクトを返す**。トリガー側でログするだけにする）:
  1. `status !== 'paid'` → `{ status: 'not_paid' }`（no-op。将来 pending を先に作る実装への防御）
  2. `listingId` か `buyerId` が欠落 → `{ status: 'missing_fields' }`（ログのみ）
  3. `getChatRoomExists(roomId)` が true → `{ status: 'already_exists' }`（冪等 no-op）
  4. `getItemSellerId(listingId)` が null → `{ status: 'item_or_seller_not_found' }`（ログのみ）
  5. `createChatRoom(roomId, { buyerId, sellerId, listingId, transactionId, createdAt: ts, lastMessageAt: ts })`
     → `{ status: 'created' }`
- 戻り値の型は判別可能な union（`'created' | 'already_exists' | 'not_paid' | 'missing_fields' | 'item_or_seller_not_found'`）。
- **items / transactions への書き込みは一切行わない**（読み取り=sellerId 取得のみ）。

## 1-3. `functions/src/index.ts`（追記のみ）

- `firebase-functions/v2/firestore` から `onDocumentCreated` を import。
- `chats` 用のストア（`ChatStore` 実装）を admin SDK で組む。
  - `getItemSellerId`: `items/{listingId}` を get し `sellerId` を返す（`mapItem` を再利用してよい）。
  - `getChatRoomExists`: `chats/{roomId}` の `.get()` → `snap.exists`。
  - `createChatRoom`: `chats/{roomId}` に `.set(data)`（merge 不要。存在チェック済み）。
- 新トリガーを export（`region: 'asia-northeast1'`、他の関数と揃える）:

```
export const onTransactionCreatedCreateChat = onDocumentCreated(
  { document: 'transactions/{txId}', region: 'asia-northeast1' },
  async (event) => {
    // 1. event.data から transaction フィールドを取り出す（txId は event.params.txId）
    // 2. createChatRoomCore(store, { transactionId, listingId, buyerId, status }) を呼ぶ
    // 3. 結果を logger でログ（created / already_exists / … を info、
    //    item_or_seller_not_found と missing_fields は warn）。
    // 4. try/catch で全例外を握り、logger.error でログするだけにする
    //    （throw して再試行させても決済には無関係だが、無限リトライを避けるため握る）。
  },
);
```

- **既存 export（createPaymentIntent / fulfillFreeTransfer / handleStripeWebhook）と
  `makeFulfillStore` は1文字も変更しない。**

## 1-4. `functions/src/__tests__/chatRoom.test.ts`（新規テスト）

`fulfill.test.ts` のインメモリストア方式を踏襲。**既存テストファイルは変更しない。**
受入テストケース（最低限）:

| # | 前提 | 期待 |
|---|---|---|
| 1 | status=paid, item に sellerId あり, ルーム未作成 | `created`。`chats` に buyerId/sellerId/listingId/transactionId/createdAt が入る |
| 2 | status=paid だがルーム既存 | `already_exists`。createChatRoom が呼ばれない |
| 3 | status!=paid（例 pending） | `not_paid`。何も書き込まない |
| 4 | listingId または buyerId 欠落 | `missing_fields`。何も書き込まない |
| 5 | item が無い/sellerId が null | `item_or_seller_not_found`。何も書き込まない |
| 6 | 全ケース共通 | items / transactions に一切書き込みが無いこと（サイズ 0 を assert） |

## 1-5. ステップ1の検証

```bash
cd functions && npm test
```
- **合格条件**: 既存24件が全て pass のまま + 新規 chatRoom テストが全て pass。
- 既存24件の pass 件数が減っていないことを出力で確認して報告する。

---

# ステップ2: firestore.rules に chats/messages のルール追加 + Rules テスト

## 目的
チャットルームとメッセージを、その取引の当事者（`buyerId` と `sellerId`）だけが読み書きできる
ようにする。**ルーム作成はサーバ（Admin SDK トリガー）限定**とし、クライアント作成を禁止する
ことで「取引が成立した二者のみのルームが存在する」を保証する。

## 2-1. `firestore.rules`（追記のみ）

既存の `match /items/{listingId}` ブロックはそのまま。同じ `match /databases/{database}/documents`
の中に以下を追加する（決定#4=個別フィールド判定）:

```
match /chats/{roomId} {
  // ルーム作成はサーバ(Admin SDK)限定。クライアントからは作れない。
  allow create: if false;
  // ルーム本体は当事者のみ read。update/delete は不可（不変）。
  allow read: if isChatParty();
  allow update, delete: if false;

  function isChatParty() {
    return request.auth != null
        && (request.auth.uid == resource.data.buyerId
         || request.auth.uid == resource.data.sellerId);
  }

  match /messages/{messageId} {
    // 当事者のみ read。
    allow read: if isMessageParty();
    // 送信: 当事者本人が、自分を senderId として、本文ありで作成。
    allow create: if isMessageParty()
                  && request.resource.data.senderId == request.auth.uid
                  && request.resource.data.text is string
                  && request.resource.data.text.size() > 0
                  && request.resource.data.text.size() <= 1000;
    // 送信後の改変・削除は不可。
    allow update, delete: if false;

    // 親ルーム doc を参照して当事者判定する。
    function isMessageParty() {
      return request.auth != null
          && (request.auth.uid == get(/databases/$(database)/documents/chats/$(roomId)).data.buyerId
           || request.auth.uid == get(/databases/$(database)/documents/chats/$(roomId)).data.sellerId);
    }
  }
}
```

> ⚠️ 要確認: メッセージ本文の最大長 1000 文字は仮。チーム UI 方針に合わせて調整可
> （変える場合は後述の Flutter 入力バリデーションと Rules を一致させる）。

## 2-2. `firestore-tests/rules.test.js`（追記のみ）

既存の `describe('items Security Rules', ...)` は変更しない。新しい `describe('chats Security Rules', ...)`
を追加。`withSecurityRulesDisabled` でルーム/メッセージを seed するヘルパを用意（既存 `seed` を参考に）。
受入テストケース:

| # | 操作 | 期待 |
|---|---|---|
| 1 | buyer がルームを read | 許可 |
| 2 | seller がルームを read | 許可 |
| 3 | 第三者がルームを read | 拒否 |
| 4 | 未ログインでルームを read | 拒否 |
| 5 | クライアントがルームを create | 拒否（`allow create: if false`） |
| 6 | buyer が senderId=自分でメッセージ create | 許可 |
| 7 | seller が senderId=自分でメッセージ create | 許可 |
| 8 | buyer が senderId=他人（なりすまし）で create | 拒否 |
| 9 | 第三者がメッセージ create | 拒否 |
| 10 | 空文字 / 1000超の本文で create | 拒否 |
| 11 | メッセージの update / delete | 拒否 |
| 12 | 第三者がメッセージ read | 拒否 |

## 2-3. ステップ2の検証

```bash
cd firestore-tests && npm run test:emulator   # JDK 21 必須（エミュレータ用）
```
- **合格条件**: 既存 items ルールテスト + 新規 chats テストが全て pass。

---

# ステップ3: Flutter チャット画面 + モデル + Repository

## 目的
当事者がメッセージをリアルタイム購読・送信できる画面を作る。既存の
`past_exam_repository.dart` の Stream パターンを踏襲する。

## 3-1. `lib/payment/models/chat_message.dart`（新規）

- フィールド: `id`（doc id）, `senderId`, `text`, `createdAt`（`DateTime?`。serverTimestamp 反映前は null）。
- `factory ChatMessage.fromFirestore(DocumentSnapshot doc)` と、送信用 `Map<String,dynamic> toMap()`
  （`createdAt` は `FieldValue.serverTimestamp()`、`senderId`, `text`）。

## 3-2. `lib/payment/models/chat_room.dart`（新規）

- フィールド: `roomId`, `buyerId`, `sellerId`, `listingId`, `transactionId`, `createdAt`。
- `fromFirestore` を用意（当面は画面で必須ではないが、将来の取引履歴入口タスクで使う）。

## 3-3. `lib/payment/services/chat_repository.dart`（新規）

`PastExamRepository` と同じ書き方で:

- `Stream<List<ChatMessage>> watchMessages(String roomId)`:
  `FirebaseFirestore.instance.collection('chats').doc(roomId).collection('messages')
   .orderBy('createdAt', descending: false).snapshots().map(...)`。
  ※過去問は降順だがチャットは**昇順**（古い→新しい）。
- `Future<void> sendMessage({required String roomId, required String senderId, required String text})`:
  `.collection('messages').add(ChatMessage(...).toMap())`。
  空文字・空白のみは送信しない（trim して空なら return）。Rules と同じ上限（1000）でガード。
- コレクション名・フィールド名はハードコードでなく `static const` にまとめる（保守性）。

## 3-4. `lib/payment/ui/screens/chat_screen.dart`（新規）

- `StatefulWidget`。コンストラクタ: `required String roomId`, `String? currentUid`,
  `ChatRepository? repository`（テスト差し替え用。省略時は `ChatRepository()` を生成）。
- `currentUid` 省略時は `FirebaseAuth.instance.currentUser?.uid` を使う（⚠️要確認B）。
- 本体: `StreamBuilder<List<ChatMessage>>(stream: repo.watchMessages(roomId), ...)`。
  - `ConnectionState.waiting` 時はローディングインジケータ（品質要件§4.1: 1秒以上はインジケータ必須）。
  - データ 0 件は空白にせず「まだメッセージはありません。最初のメッセージを送ってみましょう」等の
    ガイド表示（UI方針: データなし画面のガイド）。
  - 各メッセージは `senderId == currentUid` で左右振り分け（自分=右）。
- 下部に `TextField` + 送信ボタン（`IconButton` or `FilledButton`）。送信後に入力をクリア。
  送信中はボタンを無効化（二重送信防止）。
- `dart analyze` 警告ゼロ（`const` 化・未使用 import 除去などに注意）。

> UI は既存決済画面（`purchase_complete_screen.dart` 等）の Material 標準に合わせる。
> 凝った独自デザインは不要。チーム共通 UI 未確定のため既存に倣う。

## 3-5. `test/payment/chat_screen_test.dart`（新規 widget テスト）

`test/payment/payment_screens_test.dart` の Fake 差し替えパターンを踏襲。
`ChatRepository` を実装した Fake（`watchMessages` は `StreamController` で制御、`sendMessage` は
呼び出し記録）を注入する。受入ケース:

| # | 内容 |
|---|---|
| 1 | Stream が空リスト → 空状態ガイドが表示される |
| 2 | メッセージ2件を流す → 2件表示される（自分/相手の振り分け） |
| 3 | 入力して送信 → Fake の sendMessage が正しい roomId/senderId/text で呼ばれ、入力欄がクリアされる |
| 4 | 空文字送信 → sendMessage が呼ばれない |

## 3-6. ステップ3の検証

```bash
flutter pub get
dart analyze          # 警告ゼロが合格条件
flutter test test/payment/chat_screen_test.dart
```

> **依存パッケージは追加しない**（`cloud_firestore` / `firebase_auth` は既に pubspec にある）。
> pubspec.yaml は変更しない。

---

# ステップ4: 完了画面のボタン + navigator 改修（文言の回収）

## 目的
今日保留していた完了画面の文言「教材の受け渡し方法は出品者と連絡を取ってください。」を、
実際のチャット導線として回収する。あわせて roomId となる `transactionId` を汎用的に受け渡す。

## 4-1. navigator 改修（`flutter_payment_navigator.dart` / `payment_flow_navigation.dart`）

- `goToPurchaseComplete` のシグネチャに `transactionId`（`String`）を追加する。
  - 抽象 IF（`payment_flow_navigation.dart`）と実装（`flutter_payment_navigator.dart`）の両方を更新。
  - **既存の呼び出し箇所を全て特定し**、0円フローの呼び出し元では
    `transactionId = 'free_$listingId'` を渡す。将来の有償フローでは `pi.id` を渡せる形にする
    （引数で受け取るだけなので実装は汎用）。
- `PurchaseCompleteScreen` へ `transactionId` を渡す（settings.arguments 経由なら Map で listingId と
  transactionId を渡す。直接コンストラクタなら引数追加）。

> ⚠️ 要確認A: 呼び出し元の特定結果次第で「有償フローの完了導線が現状ない」場合は、
> 初版は0円フローのみ対応で確定してよい（有償は導線実装時に txId を渡す）。
> その判断を実装時に報告すること。

## 4-2. `purchase_complete_screen.dart` 改修

- コンストラクタに `String? transactionId`, `String? currentUid` を追加（listingId は既存）。
- 既存の Text（32行目「教材の受け渡し方法は出品者と連絡を取ってください。」）は**残す**。
  その下に **「出品者と連絡を取る」ボタン**（`FilledButton.tonal` or `OutlinedButton`）を追加し、
  押下で `ChatScreen(roomId: transactionId!, currentUid: currentUid)` へ遷移
  （`Navigator.push(MaterialPageRoute(...))`）。
  - `transactionId` が null の場合はボタンを非表示 or 無効化（安全側）。
- **`main.dart` のルートテーブルは変更しない**（`Navigator.push` で MaterialPageRoute を直接生成し、
  ルート登録を避ける。既存コメントの方針に沿う）。
- 既存の「一覧へ戻る」ボタンと `popUntil` ロジックは変更しない。

## 4-3. テスト

- `purchase_complete_screen` の既存テストがあれば壊さない（`test/payment/payment_screens_test.dart` を確認）。
- ボタン表示・遷移の widget テストを追加できるなら `chat_screen_test.dart` か
  `payment_screens_test.dart` に追記（既存テストの意味は変えない）。

## 4-4. ステップ4の検証

```bash
flutter pub get
dart analyze                        # 警告ゼロ
flutter test                        # 既存を含む全 Flutter テストが pass
```

---

## 全体の受入条件チェックリスト

- [ ] `cd functions && npm test`: 既存24件 pass のまま + chatRoom 新規テスト pass
- [ ] `cd firestore-tests && npm run test:emulator`: 既存 items + 新規 chats テスト pass
- [ ] `flutter pub get` → `dart analyze` 警告ゼロ → `flutter test` 全 pass
- [ ] 決済コア4ファイル（fulfill / freeTransfer / webhook / createPaymentIntent）に差分が無い
      （`git diff --stat` で確認）
- [ ] `functions/src/__tests__/` の既存4テストファイルに差分が無い
- [ ] `index.ts` の変更が「新トリガー export の追記」だけである
- [ ] pubspec.yaml に差分が無い（依存追加していない）
- [ ] チャットルーム作成失敗時も transaction が paid のまま（トリガーが例外を握っている）ことが
      コード上担保されている
- [ ] コミット・push をしていない（差分のみ）

## 実装完了時に報告すること

- 各ステップの検証コマンドの**実際の出力**（pass 件数を明示）
- ⚠️要確認 A / B の調査結果と、それに基づく判断（特に有償フロー導線の有無）
- 決済コア・既存テストに差分が無いことの `git diff --stat` 抜粋
