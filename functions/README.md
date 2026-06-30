# C4 取引・決済処理部 — Cloud Functions

学内情報共有システム（SIT Spot, 9班）の **教材売買の決済サーバーサイド**。
TypeScript / Firebase Cloud Functions (v2) / Stripe で実装。

## 決済方式（重要）

**Stripe Webhook 方式（A方式）に統一**。設計書 M6 の `executePayment(stripeToken)`
（Token 方式の同期決済）は **実装しない**。設計書が旧版で、M2/M3 実装および
Webhook 引き継ぎ方針と矛盾するため、Webhook 側に揃えた。

## 提供する関数

| 関数 | 種別 | 役割 |
|---|---|---|
| `createPaymentIntent` | onCall (Callable) | C5・M6。Flutter(M3) から呼ばれ、Firestore の正規価格で PaymentIntent を生成し metadata を付与 |
| `handleStripeWebhook` | onRequest (HTTP) | M4(署名検証) + M5(取引確定)。Stripe Webhook から呼ばれる |

### metadata 契約（M3 ↔ M5 の取引復元の根拠）

`createPaymentIntent` は PaymentIntent の `metadata` に**必ず**次の 2 キーを載せる。
`fulfillOrder`(M5) はこれを読んで取引を復元する。

| キー | 内容 |
|---|---|
| `listingId` | 取引対象 item のドキュメント ID（在庫ロックのキーそのもの） |
| `buyerId`   | 購入者の uid |

> `sellerId` / `lockId` は C4 に存在しない概念（ロックのキー＝`listingId`）なので契約に含めない。

### 金額の扱い

- 金額は**クライアントから受け取らない**。`createPaymentIntent` は `items/{listingId}.price`
  （正規価格）を読んで PaymentIntent の `amount` に使う。
- `fulfillOrder` でも metadata/PI の amount を信用せず、`items.price` を**再取得して照合**。
  不一致なら確定せず中断し、要返金フラグをログに残す（返金 API・管理者アラートは TODO）。
- JPY は zero-decimal currency のため `amount`(Stripe) == `price`(円) で直接比較できる。

### 冪等性

`fulfillOrder` 冒頭で `transactions/{paymentIntentId}` が既に `paid` なら no-op。
同じ payment_intent / event が再送されても二重決済しない。
fulfill 中の致命的失敗時は HTTP 500 を返し、Stripe の Webhook 自動リトライに委ねる。

## Firestore スキーマ

> `items` スキーマは教材関連の唯一の担当である C4（本担当）が確定した。
> コレクション名・フィールド名・status 値は `src/constants.ts` に集約しており、
> 変更が必要な場合はそのファイル 1 つを直せばよい。

```
items/{listingId}
  price: int                 # 正規価格（円）
  status: 'on_sale'|'pending'|'sold'   # 販売中 / 手続き中(ロック中) / 売却済
  sellerId: string
  buyerId: string            # fulfill 時に購入者を記録

transactions/{paymentIntentId}   # C4(私)所有・新規
  listingId: string
  buyerId: string
  amount: int
  status: 'pending'|'paid'
  eventId: string
  createdAt, updatedAt: Timestamp
```

## 必要な環境変数（シークレット）

ハードコード禁止。Cloud Functions v2 のシークレット（`defineSecret`）で注入する。

| 名前 | 内容 |
|---|---|
| `STRIPE_SECRET_KEY` | Stripe 秘密鍵（`sk_...`） |
| `STRIPE_WEBHOOK_SECRET` | Webhook 署名シークレット（`whsec_...`） |

### 設定（デプロイ用）

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

## デプロイ手順

```bash
cd functions
npm install
npm run build           # tsc で型チェック & lib/ 生成
# .firebaserc の "default" を実際の Firebase プロジェクト ID に変更しておく
firebase deploy --only functions
```

デプロイ後、Stripe ダッシュボードの Webhook エンドポイントに
`handleStripeWebhook` の URL を登録し、`payment_intent.succeeded` を購読する。

## ローカル動作確認

### 単体テスト（Jest）

core ロジックは SDK 非依存なので、SDK 未インストールでもテストは通る。

```bash
cd functions
npm install
npm test
```

検証内容: 署名検証の成否 / 対象外イベントの受け流し / 冪等性 / 金額不一致拒否 /
正常 fulfill / createPaymentIntent の metadata 付与・正規価格使用。

### エミュレータ

```bash
cd functions
# シークレットをローカルに渡す（例）
echo "STRIPE_SECRET_KEY=sk_test_xxx"      > .secret.local
echo "STRIPE_WEBHOOK_SECRET=whsec_xxx"   >> .secret.local
npm run serve     # build + functions/firestore エミュレータ起動
```

Stripe CLI で Webhook をローカルへ転送して E2E 確認:

```bash
stripe listen --forward-to localhost:5001/<project-id>/asia-northeast1/handleStripeWebhook
stripe trigger payment_intent.succeeded
```

## 設計思想

core ロジック（`createPaymentIntent.ts` / `webhook.ts` / `fulfill.ts`）は
**firebase / stripe SDK を一切 import しない**。依存は interface で受け取り `index.ts`
だけが実 SDK を注入する。これは C4 が C5 を抽象 interface で参照する設計と同じで、
テスト容易性と責務分離のため。
