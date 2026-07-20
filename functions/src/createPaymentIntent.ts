/**
 * C5・M6 createPaymentIntent（core）。
 * Flutter 側 M3（GatewayIntegrationModule）から Callable 経由で呼ばれる想定。
 *
 * 重要な責務分離:
 *  - 金額はクライアントから受け取らない。Firestore の items.price（正規価格）を読んで使う。
 *  - PaymentIntent.metadata に必ず {listingId, buyerId} を載せる（M5 の取引復元の根拠）。
 */
import { CoreError } from './errors';
import { CURRENCY, ITEM_STATUS, METADATA_KEYS } from './constants';
import { ItemDoc } from './types';

export interface StripePaymentIntentLike {
  id: string;
  client_secret: string | null;
}

export interface CreatePaymentIntentDeps {
  /** items/{listingId} を読む。存在しなければ null。 */
  getItem(listingId: string): Promise<ItemDoc | null>;
  /** Stripe へ PaymentIntent 生成を要求する。 */
  createStripePaymentIntent(params: {
    amount: number;
    currency: string;
    metadata: Record<string, string>;
  }): Promise<StripePaymentIntentLike>;
}

export interface CreatePaymentIntentInput {
  listingId: string;
  buyerId: string;
}

export interface CreatePaymentIntentOutput {
  clientSecret: string;
  paymentIntentId: string;
}

export async function createPaymentIntentCore(
  deps: CreatePaymentIntentDeps,
  input: CreatePaymentIntentInput,
): Promise<CreatePaymentIntentOutput> {
  const { listingId, buyerId } = input;
  if (!listingId || !buyerId) {
    throw new CoreError(400, '購入手続きに必要な情報が不足しています。');
  }

  const item = await deps.getItem(listingId);
  if (!item) {
    throw new CoreError(404, '対象の教材が見つかりません。');
  }
  // 出品者は自分の教材を購入できない（サーバ側の最終防御。UI/Rules でも弾く）。
  if (item.sellerId !== undefined && item.sellerId === buyerId) {
    throw new CoreError(403, '自分が出品した教材は購入できません。');
  }
  // 購入可能な状態: 販売中(on_sale)、または「自分が掛けた在庫ロック(pending)」。
  // ※ 購入フローは createPaymentIntent の前に M2 が pending へロックするため、
  //   自分が保持する pending を許可しないと正規フローが必ず 409 になる（本バグの真因）。
  const heldBySelf =
    item.status === ITEM_STATUS.pending && item.buyerId === buyerId;
  if (item.status !== ITEM_STATUS.onSale && !heldBySelf) {
    throw new CoreError(409, 'この教材は現在購入できません（売却済または手続き中）。');
  }
  if (!Number.isInteger(item.price) || item.price <= 0) {
    // 正規価格が壊れている状態で決済を作らない。
    throw new CoreError(500, '教材の価格情報が不正です。');
  }

  // 金額は item.price（正規価格）を使用。metadata に取引復元キーを必ず付与。
  const pi = await deps.createStripePaymentIntent({
    amount: item.price,
    currency: CURRENCY,
    metadata: {
      [METADATA_KEYS.listingId]: listingId,
      [METADATA_KEYS.buyerId]: buyerId,
    },
  });

  if (!pi.client_secret) {
    throw new CoreError(502, '決済ゲートウェイとの連携に失敗しました。');
  }
  return { clientSecret: pi.client_secret, paymentIntentId: pi.id };
}
