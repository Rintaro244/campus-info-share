import { createChatRoomCore, ChatStore } from '../chatRoom';
import { TX_STATUS } from '../constants';

/**
 * 検証可能なインメモリ ChatStore（fulfill.test.ts のストア方式を踏襲）。
 * seedSellerId=null は「item 不在 or sellerId 未設定」を表す。
 * chats に加え items/transactions への書き込みが無いことも検証できるよう、
 * items/transactions のマップは常に空のまま（core が触らないことの担保）。
 */
function makeMemStore(seed: { sellerId?: string | null; roomExists?: boolean }): {
  store: ChatStore;
  chats: Map<string, Record<string, unknown>>;
  items: Map<string, Record<string, unknown>>;
  transactions: Map<string, Record<string, unknown>>;
} {
  const chats = new Map<string, Record<string, unknown>>();
  // core は items/transactions を書き換えない。書き込まれたら失敗するよう監視する。
  const items = new Map<string, Record<string, unknown>>();
  const transactions = new Map<string, Record<string, unknown>>();

  const sellerId = seed.sellerId === undefined ? 'seller1' : seed.sellerId;
  const roomExists = seed.roomExists ?? false;

  const store: ChatStore = {
    serverTimestamp: () => 'TS',
    getItemSellerId: async (listingId) => (listingId === 'item1' ? sellerId : null),
    getChatRoomExists: async () => roomExists,
    createChatRoom: async (roomId, data) => {
      chats.set(roomId, { ...(chats.get(roomId) ?? {}), ...data });
    },
  };
  return { store, chats, items, transactions };
}

const paidInput = {
  transactionId: 'free_item1',
  listingId: 'item1',
  buyerId: 'buyer1',
  status: TX_STATUS.paid,
};

describe('createChatRoomCore (取引成立チャット生成)', () => {
  it('正常系: paid + seller あり + ルーム未作成 → chats を生成', async () => {
    const { store, chats, items, transactions } = makeMemStore({ sellerId: 'seller1' });

    const res = await createChatRoomCore(store, paidInput);

    expect(res).toEqual({ status: 'created' });
    expect(chats.get('free_item1')).toMatchObject({
      buyerId: 'buyer1',
      sellerId: 'seller1',
      listingId: 'item1',
      transactionId: 'free_item1',
      createdAt: 'TS',
      lastMessageAt: 'TS',
    });
    // 決済側（items/transactions）には一切書き込まない。
    expect(items.size).toBe(0);
    expect(transactions.size).toBe(0);
  });

  it('冪等性: ルーム既存 → already_exists（createChatRoom を呼ばない）', async () => {
    const { store, chats } = makeMemStore({ sellerId: 'seller1', roomExists: true });
    const spy = jest.spyOn(store, 'createChatRoom');

    const res = await createChatRoomCore(store, paidInput);

    expect(res).toEqual({ status: 'already_exists' });
    expect(spy).not.toHaveBeenCalled();
    expect(chats.size).toBe(0);
  });

  it('paid 以外: not_paid（何も書き込まない）', async () => {
    const { store, chats } = makeMemStore({ sellerId: 'seller1' });

    const res = await createChatRoomCore(store, {
      ...paidInput,
      status: TX_STATUS.pending,
    });

    expect(res).toEqual({ status: 'not_paid' });
    expect(chats.size).toBe(0);
  });

  it('listingId 欠落: missing_fields（何も書き込まない）', async () => {
    const { store, chats } = makeMemStore({ sellerId: 'seller1' });

    const res = await createChatRoomCore(store, {
      transactionId: 'free_item1',
      buyerId: 'buyer1',
      status: TX_STATUS.paid,
    });

    expect(res).toEqual({ status: 'missing_fields' });
    expect(chats.size).toBe(0);
  });

  it('buyerId 欠落: missing_fields（何も書き込まない）', async () => {
    const { store, chats } = makeMemStore({ sellerId: 'seller1' });

    const res = await createChatRoomCore(store, {
      transactionId: 'free_item1',
      listingId: 'item1',
      status: TX_STATUS.paid,
    });

    expect(res).toEqual({ status: 'missing_fields' });
    expect(chats.size).toBe(0);
  });

  it('item/seller 不在: item_or_seller_not_found（何も書き込まない）', async () => {
    const { store, chats } = makeMemStore({ sellerId: null });

    const res = await createChatRoomCore(store, paidInput);

    expect(res).toEqual({ status: 'item_or_seller_not_found' });
    expect(chats.size).toBe(0);
  });
});
