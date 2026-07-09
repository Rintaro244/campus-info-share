/**
 * 学内情報共有システム — C4 取引・決済処理部
 * Firestore エミュレータへのテストデータ投入（items コレクション）
 *
 * 本番の Rules は items の create をクライアントに許可していないため、
 * 動作確認用データは Admin SDK（Rules をバイパス）でエミュレータへ投入する。
 * 本番 DB には一切書き込まない（FIRESTORE_EMULATOR_HOST が必須のガード付き）。
 *
 * 使い方（リポジトリルートで。詳細は docs/emulator_manual_check.md）:
 *   NODE_PATH=./functions/node_modules node tool/seed_emulator_items.cjs
 *
 * 投入内容: on_sale の教材2件（有償 1500円 / 0円=無料譲渡）。
 * エミュレータのデータはメモリ上のみなので、再起動のたびに再実行すること。
 */
const admin = require('firebase-admin');

// 未設定なら firebase.dev.json の firestore ポートへ向ける。
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:18080';
if (!process.env.FIRESTORE_EMULATOR_HOST.includes('127.0.0.1') &&
    !process.env.FIRESTORE_EMULATOR_HOST.includes('localhost')) {
  console.error('安全ガード: FIRESTORE_EMULATOR_HOST がローカルではありません。中止します。');
  process.exit(1);
}

admin.initializeApp({ projectId: 'campus-info-share' });
const db = admin.firestore();

// フィールド名・status 値は functions/src/constants.ts の確定値に一致させること。
const seedItems = {
  demo_paid_1: {
    title: '線形代数の教科書（第2版）',
    description: '書き込みほぼなし。2年前期で使用しました。',
    price: 1500,
    status: 'on_sale',
    sellerId: 'seller_demo',
  },
  demo_free_1: {
    title: '物理学Iの過去問プリント（無料）',
    description: '無料でお譲りします。取りに来られる方限定。',
    price: 0,
    status: 'on_sale',
    sellerId: 'seller_demo',
  },
};

async function main() {
  for (const [listingId, data] of Object.entries(seedItems)) {
    await db.collection('items').doc(listingId).set(data);
  }
  const snap = await db.collection('items').get();
  console.log(`seeded: items ${snap.size} 件（emulator: ${process.env.FIRESTORE_EMULATOR_HOST}）`);
  snap.docs.forEach((d) => console.log(` - ${d.id}: ${JSON.stringify(d.data())}`));
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
