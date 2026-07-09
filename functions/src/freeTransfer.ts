/**
 * fulfillFreeTransfer（core）。0円（無料譲渡）教材の取引を確定する。
 *
 * 有償フロー（M6 createPaymentIntent → Stripe → M5 fulfillOrder）とは別経路。
 * Stripe は amount=0 の PaymentIntent を作れないため、0円は本 callable で
 * 直接確定する。ただし status -> 'sold' は Admin SDK のみという既存の
 * 安全設計（Rules でクライアント禁止）はそのまま維持する。
 *
 * 前提: 0円でも必ず M2 の在庫ロック（on_sale -> pending, buyerId=自分）を通す。
 * 検証は「price==0 かつ status==pending かつ item.buyerId==呼び出し者」。
 *
 * 冪等性（リトライ安全 + 権限安全の両立）:
 *  - transactions/{free_<listingId>} が既に paid -> 成功扱い（no-op）
 *  - item が既に sold かつ buyerId が本人 -> 成功扱い（no-op）
 *  - item が sold だが buyerId が他人 -> 409（他人の取引を成功と誤認させない）
 *
 * 金銭が動いていないため refundNeeded の概念はなく、検証失敗は CoreError を
 * throw するだけでよい（トランザクションは自動ロールバック）。
 */
import { CoreError } from './errors';
import { TX_STATUS, ITEM_STATUS, ITEM_FIELDS } from './constants';
import { FulfillStore } from './fulfill';

/** PaymentIntent が存在しないため、transactions のキーは listingId から導出する。 */
export function freeTransactionId(listingId: string): string {
  return `free_${listingId}`;
}

export interface FreeTransferInput {
  listingId: string;
  buyerId: string;
}

export type FreeTransferResult =
  | { status: 'fulfilled' }
  | { status: 'already_fulfilled' };

export async function fulfillFreeTransferCore(
  store: FulfillStore,
  input: FreeTransferInput,
): Promise<FreeTransferResult> {
  const { listingId, buyerId } = input;
  if (!listingId || !buyerId) {
    throw new CoreError(400, '手続きに必要な情報が不足しています。');
  }
  const txId = freeTransactionId(listingId);

  return store.runTransaction(async (tx) => {
    // --- 読み取りフェーズ（書き込みより前に全読み取り: Firestore 制約）---
    const existing = await tx.getTransaction(txId);
    if (existing && existing.status === TX_STATUS.paid) {
      // 冪等性: 同じ譲渡確定が再送されても二重処理しない。
      return { status: 'already_fulfilled' };
    }

    const item = await tx.getItem(listingId);
    if (!item) {
      throw new CoreError(404, '対象の教材が見つかりません。');
    }
    if (item.status === ITEM_STATUS.sold) {
      if (item.buyerId === buyerId) {
        // 冪等性: 本人へ確定済みならリトライを成功扱いにする。
        return { status: 'already_fulfilled' };
      }
      throw new CoreError(409, 'この教材は既に確定済みです。');
    }
    if (item.status !== ITEM_STATUS.pending) {
      // M2 ロック（on_sale -> pending）を通していない。手続きからやり直し。
      throw new CoreError(409, 'この教材は手続き中ではありません。購入手続きからやり直してください。');
    }
    if (item.buyerId !== buyerId) {
      throw new CoreError(409, 'この操作は許可されていません。');
    }
    if (item.price !== 0) {
      throw new CoreError(400, 'この教材は無料譲渡の対象ではありません。');
    }

    // --- 書き込みフェーズ（原子的に確定）---
    const now = store.serverTimestamp();
    tx.updateItem(listingId, {
      [ITEM_FIELDS.status]: ITEM_STATUS.sold,
      [ITEM_FIELDS.buyerId]: buyerId,
      [ITEM_FIELDS.updatedAt]: now,
    });
    tx.setTransaction(txId, {
      listingId,
      buyerId,
      amount: 0,
      status: TX_STATUS.paid,
      updatedAt: now,
      ...(existing ? {} : { createdAt: now }),
    });
    return { status: 'fulfilled' };
  });
}
