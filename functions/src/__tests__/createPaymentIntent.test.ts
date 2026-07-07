import { createPaymentIntentCore, CreatePaymentIntentDeps } from '../createPaymentIntent';
import { CoreError } from '../errors';
import { ITEM_STATUS, CURRENCY, METADATA_KEYS } from '../constants';
describe('createPaymentIntentCore', () => {
  it('正常系: 正規価格を amount に使い metadata に {listingId, buyerId} を載せる', async () => {
    const createStripePaymentIntent = jest
      .fn()
      .mockResolvedValue({ id: 'pi_1', client_secret: 'cs_1' });
    const deps: CreatePaymentIntentDeps = {
      getItem: jest.fn(async () => ({ price: 1500, status: ITEM_STATUS.onSale })),
      createStripePaymentIntent,
    };

    const out = await createPaymentIntentCore(deps, {
      listingId: 'item1',
      buyerId: 'buyer1',
    });

    expect(out).toEqual({ clientSecret: 'cs_1', paymentIntentId: 'pi_1' });
    // クライアント入力ではなく Firestore の price(1500) を使っていること。
    expect(createStripePaymentIntent).toHaveBeenCalledWith({
      amount: 1500,
      currency: CURRENCY,
      metadata: {
        [METADATA_KEYS.listingId]: 'item1',
        [METADATA_KEYS.buyerId]: 'buyer1',
      },
    });
  });

  it('入力欠落: 400', async () => {
    const deps: CreatePaymentIntentDeps = {
      getItem: jest.fn(),
      createStripePaymentIntent: jest.fn(),
    };
    await expect(
      createPaymentIntentCore(deps, { listingId: '', buyerId: 'b' }),
    ).rejects.toMatchObject({ code: 400 });
    expect(deps.getItem).not.toHaveBeenCalled();
  });

  it('item 不存在: 404', async () => {
    const deps: CreatePaymentIntentDeps = {
      getItem: jest.fn(async () => null),
      createStripePaymentIntent: jest.fn(),
    };
    await expect(
      createPaymentIntentCore(deps, { listingId: 'x', buyerId: 'b' }),
    ).rejects.toMatchObject({ code: 404 });
  });

  it('販売中でない: 409（Stripe を呼ばない）', async () => {
    const createStripePaymentIntent = jest.fn();
    const deps: CreatePaymentIntentDeps = {
      getItem: jest.fn(async () => ({ price: 1500, status: ITEM_STATUS.sold })),
      createStripePaymentIntent,
    };
    await expect(
      createPaymentIntentCore(deps, { listingId: 'x', buyerId: 'b' }),
    ).rejects.toMatchObject({ code: 409 });
    expect(createStripePaymentIntent).not.toHaveBeenCalled();
  });

  it('価格不正: 500', async () => {
    const deps: CreatePaymentIntentDeps = {
      getItem: jest.fn(async () => ({ price: 0, status: ITEM_STATUS.onSale })),
      createStripePaymentIntent: jest.fn(),
    };
    await expect(
      createPaymentIntentCore(deps, { listingId: 'x', buyerId: 'b' }),
    ).rejects.toBeInstanceOf(CoreError);
  });
});
