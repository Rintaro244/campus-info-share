/**
 * 学内情報共有システム — C4 取引・決済処理部 / C5・M6 連携
 * 共有定数。コレクション名・フィールド名・status 値・metadata キーを一元管理する。
 *
 * items スキーマは教材関連の唯一の担当である C4（本担当）が確定値として定義する。
 * 値を変える場合はこの 1 ファイルの修正だけで全箇所へ反映される。
 */

/** Firestore コレクション名。 */
export const COLLECTIONS = {
  /** 教材アイテムのコレクション。 */
  items: 'items',
  /** transactions は C4（私）所有のコレクション。 */
  transactions: 'transactions',
} as const;

/** items ドキュメントのフィールド名。 */
export const ITEM_FIELDS = {
  /** 正規価格フィールド名（円・整数）。 */
  price: 'price',
  /** ステータスフィールド名。 */
  status: 'status',
  /** 出品者 uid フィールド名。 */
  sellerId: 'sellerId',
  /** 購入者 uid フィールド名（fulfill 時に書き込む）。 */
  buyerId: 'buyerId',
  /** 教材タイトル（表示用。書き込みは将来の出品機能が担当）。 */
  title: 'title',
  /** 教材の説明（表示用・任意）。 */
  description: 'description',
  updatedAt: 'updatedAt',
} as const;

/**
 * item.status の文字列値（確定値・英語 enum）。
 *   on_sale … 販売中（購入可能）
 *   pending … 手続き中（在庫ロック中）
 *   sold    … 売却済（確定済み）
 */
export const ITEM_STATUS = {
  onSale: 'on_sale',
  pending: 'pending',
  sold: 'sold',
} as const;

/** transactions ドキュメントの status。こちらは C4 所有なので確定値。 */
export const TX_STATUS = {
  pending: 'pending',
  paid: 'paid',
} as const;

/**
 * PaymentIntent.metadata に載せるキー（M3↔M5 の取引復元契約）。
 * C5・M6 createPaymentIntent が必ずこの 2 キーを書き込み、M5 fulfillOrder がこれを読む。
 * sellerId / lockId は C4 に存在しない概念（ロックのキー＝listingId）なので契約に含めない。
 */
export const METADATA_KEYS = {
  listingId: 'listingId',
  buyerId: 'buyerId',
} as const;

/**
 * 決済通貨。JPY は zero-decimal currency のため Stripe の amount は「円」そのもの。
 * よって items.price（円・整数）と PaymentIntent.amount は単位変換なしで直接比較できる。
 */
export const CURRENCY = 'jpy';
