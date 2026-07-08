/**
 * 学内情報共有システム — C4 取引・決済処理部 / C5・M6 連携（エントリポイント）
 *
 * ここだけが firebase-admin / firebase-functions / stripe の実 SDK を import し、
 * core ロジック（createPaymentIntent / webhook / fulfill）へ依存を注入する。
 *
 * ── 決済方式について ───────────────────────────────────────────────
 * 本実装は Stripe Webhook 方式(A方式)。設計書 M6 の executePayment(stripeToken)
 * 同期決済（Token方式）は実装しない（設計書が旧版で M2/M3・Webhook 方針と矛盾するため）。
 *
 * ── 必要な環境変数（シークレット。ハードコード禁止）──────────────────
 *   STRIPE_SECRET_KEY      … Stripe 秘密鍵
 *   STRIPE_WEBHOOK_SECRET  … Webhook 署名シークレット（whsec_...）
 * 設定方法は functions/README.md を参照。
 */
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import Stripe from 'stripe';

import { COLLECTIONS, ITEM_FIELDS } from './constants';
import { CoreError } from './errors';
import { ItemDoc, TransactionDoc, StripeEventLike } from './types';
import { createPaymentIntentCore } from './createPaymentIntent';
import { fulfillFreeTransferCore } from './freeTransfer';
import { handleWebhookCore } from './webhook';
import { fulfillOrderCore, FulfillStore, TxOps } from './fulfill';

admin.initializeApp();
const db = admin.firestore();

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');

// ── Firestore マッピング ─────────────────────────────────────────────
function mapItem(data: FirebaseFirestore.DocumentData): ItemDoc {
  return {
    price: data[ITEM_FIELDS.price],
    status: data[ITEM_FIELDS.status],
    sellerId: data[ITEM_FIELDS.sellerId],
    buyerId: data[ITEM_FIELDS.buyerId],
  };
}

async function getItem(listingId: string): Promise<ItemDoc | null> {
  const snap = await db.collection(COLLECTIONS.items).doc(listingId).get();
  return snap.exists ? mapItem(snap.data() as FirebaseFirestore.DocumentData) : null;
}

/** CoreError(code) → HttpsError へ変換。 */
function toHttpsError(e: unknown): HttpsError {
  if (e instanceof CoreError) {
    switch (e.code) {
      case 400:
        return new HttpsError('invalid-argument', e.message);
      case 404:
        return new HttpsError('not-found', e.message);
      case 409:
        return new HttpsError('failed-precondition', e.message);
      case 502:
      case 503:
        return new HttpsError('unavailable', e.message);
      default:
        return new HttpsError('internal', e.message);
    }
  }
  logger.error('unexpected error in createPaymentIntent', e);
  return new HttpsError('internal', '内部エラーが発生しました。');
}

// ── (1) C5・M6 createPaymentIntent（Callable）────────────────────────
export const createPaymentIntent = onCall(
  { secrets: [STRIPE_SECRET_KEY], region: 'asia-northeast1' },
  async (request) => {
    const buyerId = request.auth?.uid;
    if (!buyerId) {
      throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }
    const listingId = request.data?.listingId;
    if (typeof listingId !== 'string' || listingId.length === 0) {
      throw new HttpsError('invalid-argument', 'listingId が不正です。');
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY.value());
    try {
      return await createPaymentIntentCore(
        {
          getItem,
          createStripePaymentIntent: (p) =>
            stripe.paymentIntents.create({
              amount: p.amount,
              currency: p.currency,
              metadata: p.metadata,
            }),
        },
        { listingId, buyerId },
      );
    } catch (e) {
      throw toHttpsError(e);
    }
  },
);

// ── (2) fulfillFreeTransfer（Callable・0円/無料譲渡の確定）───────────
// Stripe を使わないため secrets 指定は不要。ストア・エラー変換は既存を再利用。
export const fulfillFreeTransfer = onCall(
  { region: 'asia-northeast1' },
  async (request) => {
    const buyerId = request.auth?.uid;
    if (!buyerId) {
      throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }
    const listingId = request.data?.listingId;
    if (typeof listingId !== 'string' || listingId.length === 0) {
      throw new HttpsError('invalid-argument', 'listingId が不正です。');
    }

    try {
      return await fulfillFreeTransferCore(makeFulfillStore(), {
        listingId,
        buyerId,
      });
    } catch (e) {
      throw toHttpsError(e);
    }
  },
);

// ── fulfill 用 Firestore ストア（admin トランザクションを TxOps に適合）──
function makeFulfillStore(): FulfillStore {
  return {
    // admin.firestore.FieldValue は firebase-admin v12 の ESM interop で
    // undefined になるため、サブパスから直接 import した FieldValue を使う。
    serverTimestamp: () => FieldValue.serverTimestamp(),
    runTransaction: (work) =>
      db.runTransaction(async (t) => {
        const ops: TxOps = {
          getItem: async (listingId) => {
            const snap = await t.get(db.collection(COLLECTIONS.items).doc(listingId));
            return snap.exists ? mapItem(snap.data() as FirebaseFirestore.DocumentData) : null;
          },
          getTransaction: async (paymentIntentId) => {
            const snap = await t.get(
              db.collection(COLLECTIONS.transactions).doc(paymentIntentId),
            );
            return snap.exists ? (snap.data() as TransactionDoc) : null;
          },
          updateItem: (listingId, data) => {
            t.set(db.collection(COLLECTIONS.items).doc(listingId), data, { merge: true });
          },
          setTransaction: (paymentIntentId, data) => {
            t.set(db.collection(COLLECTIONS.transactions).doc(paymentIntentId), data, {
              merge: true,
            });
          },
        };
        return work(ops);
      }),
  };
}

// ── (3) M4 handleStripeWebhook + M5 fulfillOrder（HTTP）──────────────
export const handleStripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET], region: 'asia-northeast1' },
  async (req, res) => {
    const stripe = new Stripe(STRIPE_SECRET_KEY.value());
    const signature = req.headers['stripe-signature'] as string | undefined;
    const store = makeFulfillStore();

    try {
      const result = await handleWebhookCore(
        {
          // 署名検証は必ず rawBody（生バイト列）に対して行う。
          // Stripe.Event は構造的に StripeEventLike を満たすため二段キャストで受ける。
          constructEvent: (payload, sig) =>
            stripe.webhooks.constructEvent(
              payload,
              sig,
              STRIPE_WEBHOOK_SECRET.value(),
            ) as unknown as StripeEventLike,
          fulfillOrder: (pi, eventId) => fulfillOrderCore(store, pi, eventId),
        },
        req.rawBody, // firebase の onRequest は rawBody を提供する
        signature,
      );

      // 確定できたが返金が必要なケース（金額不一致・item 消失）はログ + TODO。
      const body = result.body as { result?: { refundNeeded?: boolean } };
      if (body?.result?.refundNeeded) {
        // TODO: Stripe 返金 API 呼び出し + 管理者への緊急アラート（通知機構のフック）。
        logger.error('[M5] refundNeeded: 決済成功だが確定不可。要返金・要調査。', body.result);
      }
      res.status(result.status).json(result.body);
    } catch (e) {
      // fulfill 中の致命的データ不整合（成功後の Firestore 反映失敗）。
      // 500 を返すと Stripe が webhook を自動リトライする（= リトライ機構）。
      // TODO: それでも失敗が続く場合に備え、管理者への緊急アラート機構をここにフックする。
      logger.error('[M4/M5] webhook 処理失敗。Stripe にリトライさせる。', e);
      res.status(500).json({ error: 'internal' });
    }
  },
);
