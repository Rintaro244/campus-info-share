/**
 * 取引成立時の購入者⇄出品者チャットルーム生成（core）。
 *
 * transactions/{txId} の新規作成（status=paid）を契機に、その取引の当事者2名の
 * チャットルーム chats/{txId} を1件生成する。roomId は transactionId をそのまま使う。
 *
 * ── 決済との分離（最重要）─────────────────────────────────────────────
 * 本 core が呼ばれる時点で決済確定（transaction=paid）は既にコミット済み。
 * ここでの失敗はルーム生成を諦めるだけで、決済（paid）には一切影響しない。
 * そのため例外を throw せず、必ず結果オブジェクトを返す（呼び出し側はログするのみ）。
 *
 * ── SDK 非依存 ───────────────────────────────────────────────────────
 * 決済コア（fulfill / freeTransfer）と同じく firebase-admin を import せず、
 * 依存は ChatStore interface で受け取る（= インメモリで単体テスト可能）。
 *
 * seller は transactions に載っていないため（TransactionDoc は sellerId を持たない）、
 * items/{listingId}.sellerId を取得して保存する。
 */
import { TX_STATUS } from './constants';

/** transactions ドキュメントから core が使う部分。 */
export interface TransactionCreatedInput {
  /** roomId として使う transactionId（= transactions のドキュメント ID）。 */
  transactionId: string;
  listingId?: string;
  buyerId?: string;
  status?: string;
}

/** チャットルーム生成の依存。実装は index.ts で admin SDK により注入する。 */
export interface ChatStore {
  /** items/{listingId}.sellerId を返す。item 不在・sellerId 未設定なら null。 */
  getItemSellerId(listingId: string): Promise<string | null>;
  /** chats/{roomId} が既に存在するか（冪等性チェック）。 */
  getChatRoomExists(roomId: string): Promise<boolean>;
  /** chats/{roomId} を新規作成する。 */
  createChatRoom(roomId: string, data: Record<string, unknown>): Promise<void>;
  /** サーバタイムスタンプのセンチネル。 */
  serverTimestamp(): unknown;
}

export type CreateChatRoomResult =
  | { status: 'created' }
  | { status: 'already_exists' }
  | { status: 'not_paid' }
  | { status: 'missing_fields' }
  | { status: 'item_or_seller_not_found' };

export async function createChatRoomCore(
  store: ChatStore,
  input: TransactionCreatedInput,
): Promise<CreateChatRoomResult> {
  const { transactionId, listingId, buyerId, status } = input;

  // 1. paid 以外は対象外。将来 pending の transaction を先に作る実装への防御。
  if (status !== TX_STATUS.paid) {
    return { status: 'not_paid' };
  }

  // 2. 復元に必要なフィールドが欠けていれば作れない。
  if (!listingId || !buyerId) {
    return { status: 'missing_fields' };
  }

  // 3. 冪等性: 既にルームがあれば no-op（onDocumentCreated の再試行に安全）。
  const exists = await store.getChatRoomExists(transactionId);
  if (exists) {
    return { status: 'already_exists' };
  }

  // 4. seller を items から取得（transactions は sellerId を持たないため）。
  const sellerId = await store.getItemSellerId(listingId);
  if (!sellerId) {
    return { status: 'item_or_seller_not_found' };
  }

  // 5. ルーム生成。read/write するのは chats のみ。items/transactions は書き換えない。
  const now = store.serverTimestamp();
  await store.createChatRoom(transactionId, {
    buyerId,
    sellerId,
    listingId,
    transactionId,
    createdAt: now,
    lastMessageAt: now,
  });
  return { status: 'created' };
}
