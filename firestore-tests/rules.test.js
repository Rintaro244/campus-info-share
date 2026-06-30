/**
 * Firestore Security Rules ユニットテスト（firestore.rules / items）。
 *
 * 実行には Firestore エミュレータ（要 Java）が必要。リポジトリルートで:
 *   cd firestore-tests && npm install
 *   npm run test:emulator        # firebase emulators:exec が自動でエミュレータ起動
 * もしくはエミュレータを別途起動済みなら `npm test`。
 */
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-campus-info-share';
const LISTING = 'item1';
const BUYER = 'buyer1';
const OTHER = 'buyer2';

/** 既存 item の初期データ（販売中）。 */
const onSaleItem = { price: 1000, status: 'on_sale', sellerId: 'seller1' };
/** ロック済み（buyer1 が保持）。 */
const pendingItem = {
  price: 1000,
  status: 'pending',
  sellerId: 'seller1',
  buyerId: BUYER,
};

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

/** Rules を無効化して item を seed する。 */
async function seed(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('items').doc(id).set(data);
  });
}

const authed = (uid) => testEnv.authenticatedContext(uid).firestore();
const unauthed = () => testEnv.unauthenticatedContext().firestore();

describe('items Security Rules', () => {
  test('① read は未ログインでも許可', async () => {
    await seed(LISTING, onSaleItem);
    await assertSucceeds(unauthed().collection('items').doc(LISTING).get());
  });

  test('② 正常ロック: on_sale -> pending + 自分の buyerId は許可', async () => {
    await seed(LISTING, onSaleItem);
    await assertSucceeds(
      authed(BUYER).collection('items').doc(LISTING).update({
        status: 'pending',
        buyerId: BUYER,
      }),
    );
  });

  test('③ 未ログインのロックは拒否', async () => {
    await seed(LISTING, onSaleItem);
    await assertFails(
      unauthed().collection('items').doc(LISTING).update({
        status: 'pending',
        buyerId: BUYER,
      }),
    );
  });

  test('④ price を変更しようとすると拒否', async () => {
    await seed(LISTING, onSaleItem);
    await assertFails(
      authed(BUYER).collection('items').doc(LISTING).update({
        status: 'pending',
        buyerId: BUYER,
        price: 9999,
      }),
    );
  });

  test('⑤ クライアントから直接 sold への変更は拒否', async () => {
    await seed(LISTING, onSaleItem);
    await assertFails(
      authed(BUYER).collection('items').doc(LISTING).update({
        status: 'sold',
        buyerId: BUYER,
      }),
    );
  });

  test('⑥ 他人の uid を buyerId にしてロックは拒否', async () => {
    await seed(LISTING, onSaleItem);
    await assertFails(
      authed(BUYER).collection('items').doc(LISTING).update({
        status: 'pending',
        buyerId: OTHER,
      }),
    );
  });

  test('⑦ ロック保持者本人の unlock は許可', async () => {
    await seed(LISTING, pendingItem);
    await assertSucceeds(
      authed(BUYER).collection('items').doc(LISTING).update({
        status: 'on_sale',
        buyerId: null,
      }),
    );
  });

  test('⑧ 非保持者の unlock は拒否', async () => {
    await seed(LISTING, pendingItem);
    await assertFails(
      authed(OTHER).collection('items').doc(LISTING).update({
        status: 'on_sale',
        buyerId: null,
      }),
    );
  });

  test('⑨ create / delete はクライアント不可', async () => {
    await assertFails(
      authed(BUYER).collection('items').doc('new').set(onSaleItem),
    );
    await seed(LISTING, onSaleItem);
    await assertFails(authed(BUYER).collection('items').doc(LISTING).delete());
  });
});
