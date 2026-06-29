/**
 * 学内情報共有システム — C4 取引・決済処理部 / C5・M6 連携
 * 共有定数。コレクション名・フィールド名・status 値・metadata キーを一元管理する。
 *
 * 設計思想: items スキーマは「教材売買担当（他班所有）」の実物に合わせる必要があるが、
 * 実コレクション名・フィールド名・status 文字列値はソースコードからは読み取れなかった
 * （C5 具象が未提供で、status は c5_interfaces.dart のコメントにしか現れない）。
 * そのため仮値を本ファイルに集約し TODO を付す。確定後はこの 1 ファイルの修正で済む。
 */

/** Firestore コレクション名。 */
export const COLLECTIONS = {
  /** TODO(items担当に要確認): 教材アイテムの実コレクション名。 */
  items: 'items',
  /** transactions は C4（私）所有の新規コレクション。 */
  transactions: 'transactions',
} as const;

/** items ドキュメントのフィールド名。 */
export const ITEM_FIELDS = {
  /** TODO(items担当に要確認): 正規価格フィールド名（円・整数）。 */
  price: 'price',
  /** TODO(items担当に要確認): ステータスフィールド名。 */
  status: 'status',
  /** TODO(items担当に要確認): 出品者 uid フィールド名。 */
  sellerId: 'sellerId',
  /** TODO(items担当に要確認): 購入者 uid フィールド名（fulfill 時に書き込む）。 */
  buyerId: 'buyerId',
  updatedAt: 'updatedAt',
} as const;

/**
 * item.status の文字列値。
 * TODO(items担当に要確認): 実値は c5_interfaces.dart のコメント（販売中/手続き中/売却済）
 * にしか現れず、実際に保存される文字列が未確定のため仮値。英語 enum 等に変わる可能性あり。
 */
export const ITEM_STATUS = {
  onSale: '販売中',
  pending: '手続き中',
  sold: '売却済',
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
