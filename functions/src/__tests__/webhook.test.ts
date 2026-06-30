import { handleWebhookCore, WebhookDeps } from '../webhook';
import { StripeEventLike, PaymentIntentData } from '../types';

function succeededEvent(pi: Partial<PaymentIntentData> = {}): StripeEventLike {
  return {
    id: 'evt_1',
    type: 'payment_intent.succeeded',
    data: {
      object: {
        id: 'pi_1',
        amount: 1500,
        metadata: { listingId: 'item1', buyerId: 'buyer1' },
        ...pi,
      },
    },
  };
}

describe('handleWebhookCore (M4)', () => {
  it('署名ヘッダ欠落: 400', async () => {
    const deps: WebhookDeps = {
      constructEvent: jest.fn(),
      fulfillOrder: jest.fn(),
    };
    const res = await handleWebhookCore(deps, 'raw', undefined);
    expect(res.status).toBe(400);
    expect(deps.constructEvent).not.toHaveBeenCalled();
  });

  it('署名検証失敗: 400（fulfill しない）', async () => {
    const fulfillOrder = jest.fn();
    const deps: WebhookDeps = {
      constructEvent: jest.fn(() => {
        throw new Error('bad sig');
      }),
      fulfillOrder,
    };
    const res = await handleWebhookCore(deps, 'raw', 'sig');
    expect(res.status).toBe(400);
    expect(fulfillOrder).not.toHaveBeenCalled();
  });

  it('対象外イベント: 200 で受け流し fulfill しない', async () => {
    const fulfillOrder = jest.fn();
    const deps: WebhookDeps = {
      constructEvent: jest.fn(() => ({
        id: 'evt_2',
        type: 'payment_intent.created',
        data: { object: { id: 'pi_2', amount: 1, metadata: {} } },
      })),
      fulfillOrder,
    };
    const res = await handleWebhookCore(deps, 'raw', 'sig');
    expect(res.status).toBe(200);
    expect(fulfillOrder).not.toHaveBeenCalled();
  });

  it('payment_intent.succeeded: M5 を呼び 200 を返す', async () => {
    const fulfillOrder = jest.fn().mockResolvedValue({ status: 'fulfilled' });
    const deps: WebhookDeps = {
      constructEvent: jest.fn(() => succeededEvent()),
      fulfillOrder,
    };
    const res = await handleWebhookCore(deps, 'raw', 'sig');
    expect(res.status).toBe(200);
    expect(fulfillOrder).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'pi_1', amount: 1500 }),
      'evt_1',
    );
  });

  it('fulfill 例外は伝播する（呼び出し側が 500 を返す想定）', async () => {
    const deps: WebhookDeps = {
      constructEvent: jest.fn(() => succeededEvent()),
      fulfillOrder: jest.fn().mockRejectedValue(new Error('firestore down')),
    };
    await expect(handleWebhookCore(deps, 'raw', 'sig')).rejects.toThrow('firestore down');
  });
});
