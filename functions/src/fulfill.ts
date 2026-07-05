/**
 * M5 fulfillOrder（core）。決済成功イベントを受けて取引を確定する。
 *
 * 確定は Firestore トランザクション内で原子的に行う:
 *   1. metadata から取引（listingId, buyerId）を復元
 *   2. 金額照合: metadata/PI の amount を鵜呑みにせず items.price（正規価格）を再取得して照合
 *   3. item.status を 手続き中 → 売却済、item に購入者(buyerId)を記録
 *   4. transactions/{paymentIntentId} を paid に
 *   5. 冪等性: 既に paid なら no-op
 *
 * ロールバック / 返金方針:
 *  - トランザクション内の例外は全更新が自動ロールバックされる（Firestore の原子性）。
 *  - 「決済は成功したが確定できない」ケース（金額不一致・item 消失）は fulfill せず中断し、
 *    refundNeeded=true を返す。呼び出し側で Stripe 返金 + 緊急アラートを行う想定（TODO）。
 *  - 「確定はしたが after-commit の副作用に失敗」は本 core では発生しない（副作用は持たない）。
 */
import { TX_STATUS, ITEM_STATUS, ITEM_FIELDS } from './constants';
import { ItemDoc, PaymentIntentData, TransactionDoc } from './types';
import { METADATA_KEYS } from './constants';

/** トランザクション内で使える操作。読み取りは全て書き込みより前に呼ぶこと（Firestore 制約）。 */
export interface TxOps {
  getItem(listingId: string): Promise<ItemDoc | null>;
  getTransaction(paymentIntentId: string): Promise<TransactionDoc | null>;
  updateItem(listingId: string, data: Record<string, unknown>): void;
  setTransaction(paymentIntentId: string, data: Record<string, unknown>): void;
}

export interface FulfillStore {
  runTransaction<T>(work: (tx: TxOps) => Promise<T>): Promise<T>;
  /** サーバタイムスタンプのセンチネル（実装は FieldValue.serverTimestamp()）。 */
  serverTimestamp(): unknown;
}

export type FulfillResult =
  | { status: 'fulfilled' }
  | { status: 'already_fulfilled' }
  | { status: 'missing_metadata' }
  | { status: 'item_not_found'; refundNeeded: true }
  | { status: 'amount_mismatch'; refundNeeded: true; expected: number; actual: number };

export async function fulfillOrderCore(
  store: FulfillStore,
  pi: PaymentIntentData,
  eventId: string,
): Promise<FulfillResult> {
  const listingId = pi.metadata[METADATA_KEYS.listingId];
  const buyerId = pi.metadata[METADATA_KEYS.buyerId];

  if (!listingId || !buyerId) {
    // 復元不能。fulfill しない。決済自体は成立しているため要調査（返金要否は人手判断）。
    console.error(
      `[M5] metadata 欠落で取引復元不能: paymentIntent=${pi.id} eventId=${eventId}`,
    );
    return { status: 'missing_metadata' };
  }

  return store.runTransaction(async (tx) => {
    // --- 読み取りフェーズ ---
    const existing = await tx.getTransaction(pi.id);
    if (existing && existing.status === TX_STATUS.paid) {
      // 冪等性: 同じ payment_intent が再送されても二重決済しない。
      return { status: 'already_fulfilled' };
    }

    const item = await tx.getItem(listingId);
    if (!item) {
      // 決済成功後に item が消えた異常系。確定できないので返金が必要。
      console.error(
        `[M5] item 不在で確定不能: listingId=${listingId} paymentIntent=${pi.id}`,
      );
      return { status: 'item_not_found', refundNeeded: true };
    }

    // 金額照合: metadata/PI の amount を信用せず正規価格と突き合わせる。
    if (item.price !== pi.amount) {
      console.error(
        `[M5] 金額不一致 確定拒否: listingId=${listingId} expected=${item.price} actual=${pi.amount}`,
      );
      return {
        status: 'amount_mismatch',
        refundNeeded: true,
        expected: item.price,
        actual: pi.amount,
      };
    }

    // --- 書き込みフェーズ（原子的に確定）---
    const now = store.serverTimestamp();
    tx.updateItem(listingId, {
      [ITEM_FIELDS.status]: ITEM_STATUS.sold, // 手続き中 → 売却済（= ロック解除も兼ねる）
      [ITEM_FIELDS.buyerId]: buyerId,
      [ITEM_FIELDS.updatedAt]: now,
    });
    tx.setTransaction(pi.id, {
      listingId,
      buyerId,
      amount: pi.amount,
      status: TX_STATUS.paid,
      eventId,
      updatedAt: now,
      ...(existing ? {} : { createdAt: now }),
    });
    return { status: 'fulfilled' };
  });
}
