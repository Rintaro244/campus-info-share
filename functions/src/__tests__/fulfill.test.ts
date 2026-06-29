import { fulfillOrderCore, FulfillStore, TxOps } from '../fulfill';
import { ITEM_STATUS, TX_STATUS, ITEM_FIELDS } from '../constants';
import { ItemDoc, PaymentIntentData, TransactionDoc } from '../types';

/** トランザクションの原子性を模した、検証可能なインメモリストア。 */
function makeMemStore(seed: {
  item?: ItemDoc | null;
  transaction?: TransactionDoc | null;
}): {
  store: FulfillStore;
  items: Map<string, Record<string, unknown>>;
  transactions: Map<string, Record<string, unknown>>;
} {
  const items = new Map<string, Record<string, unknown>>();
  const transactions = new Map<string, Record<string, unknown>>();

  const currentItem = seed.item === undefined ? null : seed.item;
  const currentTx = seed.transaction === undefined ? null : seed.transaction;

  const store: FulfillStore = {
    serverTimestamp: () => 'TS',
    runTransaction: async (work) => {
      const ops: TxOps = {
        getItem: async (listingId) =>
          listingId === 'item1' ? currentItem : null,
        getTransaction: async (pid) => (pid === 'pi_1' ? currentTx : null),
        updateItem: (listingId, data) => {
          items.set(listingId, { ...(items.get(listingId) ?? {}), ...data });
        },
        setTransaction: (pid, data) => {
          transactions.set(pid, { ...(transactions.get(pid) ?? {}), ...data });
        },
      };
      return work(ops);
    },
  };
  return { store, items, transactions };
}

const pi: PaymentIntentData = {
  id: 'pi_1',
  amount: 1500,
  metadata: { listingId: 'item1', buyerId: 'buyer1' },
};

describe('fulfillOrderCore (M5)', () => {
  it('正常系: 売却済へ更新し transactions を paid にする', async () => {
    const { store, items, transactions } = makeMemStore({
      item: { price: 1500, status: ITEM_STATUS.pending },
      transaction: null,
    });

    const res = await fulfillOrderCore(store, pi, 'evt_1');

    expect(res).toEqual({ status: 'fulfilled' });
    expect(items.get('item1')).toMatchObject({
      [ITEM_FIELDS.status]: ITEM_STATUS.sold,
      [ITEM_FIELDS.buyerId]: 'buyer1',
    });
    expect(transactions.get('pi_1')).toMatchObject({
      listingId: 'item1',
      buyerId: 'buyer1',
      amount: 1500,
      status: TX_STATUS.paid,
      eventId: 'evt_1',
    });
  });

  it('冪等性: 既に paid なら no-op', async () => {
    const { store, items, transactions } = makeMemStore({
      item: { price: 1500, status: ITEM_STATUS.sold },
      transaction: {
        listingId: 'item1',
        buyerId: 'buyer1',
        amount: 1500,
        status: TX_STATUS.paid,
      },
    });

    const res = await fulfillOrderCore(store, pi, 'evt_1');

    expect(res).toEqual({ status: 'already_fulfilled' });
    expect(items.size).toBe(0);
    expect(transactions.size).toBe(0);
  });

  it('金額不一致: 確定せず refundNeeded', async () => {
    const { store, items, transactions } = makeMemStore({
      item: { price: 2000, status: ITEM_STATUS.pending }, // 正規価格 != PI.amount(1500)
      transaction: null,
    });

    const res = await fulfillOrderCore(store, pi, 'evt_1');

    expect(res).toEqual({
      status: 'amount_mismatch',
      refundNeeded: true,
      expected: 2000,
      actual: 1500,
    });
    expect(items.size).toBe(0);
    expect(transactions.size).toBe(0);
  });

  it('metadata 欠落: 中断（runTransaction を呼ばない）', async () => {
    const { store } = makeMemStore({ item: { price: 1500, status: ITEM_STATUS.pending } });
    const spy = jest.spyOn(store, 'runTransaction');

    const res = await fulfillOrderCore(
      store,
      { id: 'pi_1', amount: 1500, metadata: { buyerId: 'buyer1' } },
      'evt_1',
    );

    expect(res).toEqual({ status: 'missing_metadata' });
    expect(spy).not.toHaveBeenCalled();
  });

  it('item 不在: 確定せず refundNeeded', async () => {
    const { store, items, transactions } = makeMemStore({ item: null });

    const res = await fulfillOrderCore(store, pi, 'evt_1');

    expect(res).toEqual({ status: 'item_not_found', refundNeeded: true });
    expect(items.size).toBe(0);
    expect(transactions.size).toBe(0);
  });
});
