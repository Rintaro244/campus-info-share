import { fulfillFreeTransferCore, freeTransactionId } from '../freeTransfer';
import { CoreError } from '../errors';
import { ITEM_STATUS, TX_STATUS, ITEM_FIELDS } from '../constants';
import { ItemDoc, TransactionDoc } from '../types';
import { FulfillStore, TxOps } from '../fulfill';

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
        getTransaction: async (pid) =>
          pid === freeTransactionId('item1') ? currentTx : null,
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

const input = { listingId: 'item1', buyerId: 'buyer1' };

describe('fulfillFreeTransferCore', () => {
  it('正常系: sold へ更新し transactions/free_<listingId> を paid にする', async () => {
    const { store, items, transactions } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.pending, buyerId: 'buyer1' },
      transaction: null,
    });

    const res = await fulfillFreeTransferCore(store, input);

    expect(res).toEqual({ status: 'fulfilled' });
    expect(items.get('item1')).toMatchObject({
      [ITEM_FIELDS.status]: ITEM_STATUS.sold,
      [ITEM_FIELDS.buyerId]: 'buyer1',
    });
    expect(transactions.get('free_item1')).toMatchObject({
      listingId: 'item1',
      buyerId: 'buyer1',
      amount: 0,
      status: TX_STATUS.paid,
    });
  });

  it('冪等性: transactions が既に paid なら no-op で成功扱い', async () => {
    const { store, items, transactions } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.sold, buyerId: 'buyer1' },
      transaction: {
        listingId: 'item1',
        buyerId: 'buyer1',
        amount: 0,
        status: TX_STATUS.paid,
      },
    });

    const res = await fulfillFreeTransferCore(store, input);

    expect(res).toEqual({ status: 'already_fulfilled' });
    expect(items.size).toBe(0);
    expect(transactions.size).toBe(0);
  });

  it('冪等性: item が本人へ sold 済みなら no-op で成功扱い', async () => {
    const { store, items } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.sold, buyerId: 'buyer1' },
      transaction: null,
    });

    const res = await fulfillFreeTransferCore(store, input);

    expect(res).toEqual({ status: 'already_fulfilled' });
    expect(items.size).toBe(0);
  });

  it('他人へ sold 済み: 409（成功と誤認させない）', async () => {
    const { store } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.sold, buyerId: 'other' },
    });

    await expect(fulfillFreeTransferCore(store, input)).rejects.toMatchObject({
      code: 409,
    });
  });

  it('item 不在: 404', async () => {
    const { store } = makeMemStore({ item: null });

    await expect(fulfillFreeTransferCore(store, input)).rejects.toMatchObject({
      code: 404,
    });
  });

  it('ロック未通過（on_sale のまま）: 409', async () => {
    const { store, items } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.onSale },
    });

    await expect(fulfillFreeTransferCore(store, input)).rejects.toMatchObject({
      code: 409,
    });
    expect(items.size).toBe(0);
  });

  it('ロック保持者が他人: 409', async () => {
    const { store } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.pending, buyerId: 'other' },
    });

    await expect(fulfillFreeTransferCore(store, input)).rejects.toMatchObject({
      code: 409,
    });
  });

  it('price が 0 でない: 400（有償フローへ誘導）', async () => {
    const { store, items } = makeMemStore({
      item: { price: 1500, status: ITEM_STATUS.pending, buyerId: 'buyer1' },
    });

    await expect(fulfillFreeTransferCore(store, input)).rejects.toMatchObject({
      code: 400,
    });
    expect(items.size).toBe(0);
  });

  it('入力欠落: 400（runTransaction を呼ばない）', async () => {
    const { store } = makeMemStore({
      item: { price: 0, status: ITEM_STATUS.pending, buyerId: 'buyer1' },
    });
    const spy = jest.spyOn(store, 'runTransaction');

    await expect(
      fulfillFreeTransferCore(store, { listingId: '', buyerId: 'buyer1' }),
    ).rejects.toBeInstanceOf(CoreError);
    expect(spy).not.toHaveBeenCalled();
  });
});
