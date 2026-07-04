/**
 * M4 handleStripeWebhook（core）。
 *
 *  - 署名検証（constructEvent）に失敗したら 400。
 *  - payment_intent.succeeded のみ M5(fulfillOrder) を呼ぶ。それ以外は 200 で受け流す。
 *  - 冪等性は M5 側（transactions/{paymentIntentId} の paid チェック）で担保する。
 *  - fulfillOrder が throw（インフラ障害等）した場合は core では握りつぶさず伝播させ、
 *    呼び出し側(index.ts)が 500 を返して Stripe にリトライさせる。
 */
import { StripeEventLike, PaymentIntentData } from './types';
import { FulfillResult } from './fulfill';

export interface WebhookDeps {
  /** stripe.webhooks.constructEvent 相当。署名不正なら throw。 */
  constructEvent(payload: string | Buffer, signature: string): StripeEventLike;
  fulfillOrder(pi: PaymentIntentData, eventId: string): Promise<FulfillResult>;
}

export interface WebhookResponse {
  status: number;
  body: unknown;
}

export async function handleWebhookCore(
  deps: WebhookDeps,
  payload: string | Buffer,
  signature: string | undefined,
): Promise<WebhookResponse> {
  if (!signature) {
    return { status: 400, body: { error: 'missing stripe-signature header' } };
  }

  let event: StripeEventLike;
  try {
    event = deps.constructEvent(payload, signature);
  } catch (e) {
    // 署名検証失敗 = 改ざん/誤送信。fulfill は一切行わない。
    return { status: 400, body: { error: 'invalid signature' } };
  }

  if (event.type !== 'payment_intent.succeeded') {
    // 関心のないイベントは ACK のみ（再送防止）。
    return { status: 200, body: { received: true, ignored: event.type } };
  }

  // fulfill の例外はここで catch しない → 呼び出し側が 500 を返し Stripe が再送する。
  const result = await deps.fulfillOrder(event.data.object, event.id);
  return { status: 200, body: { received: true, result } };
}
