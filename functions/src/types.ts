/**
 * core ロジックが依存する最小限の型と依存性インターフェース。
 * firebase-admin / stripe の型をここで参照しないことで、core を SDK 非依存に保つ
 * （= 注入されたモックでテスト可能。C4 の「C5 を抽象 interface で参照」と同じ思想）。
 */

/** items ドキュメントの読み取りビュー（必要なフィールドのみ）。 */
export interface ItemDoc {
  /** 正規価格（円・整数）。 */
  price: number;
  status: string;
  sellerId?: string;
}

/** transactions ドキュメント。 */
export interface TransactionDoc {
  listingId: string;
  buyerId: string;
  amount: number;
  status: string;
  eventId?: string;
}

/** Stripe PaymentIntent のうち core が使う部分。 */
export interface PaymentIntentData {
  id: string;
  /** zero-decimal(JPY) のため円そのもの。 */
  amount: number;
  metadata: Record<string, string | undefined>;
}

/** Stripe webhook イベントのうち core が使う部分。 */
export interface StripeEventLike {
  id: string;
  type: string;
  data: { object: PaymentIntentData };
}
