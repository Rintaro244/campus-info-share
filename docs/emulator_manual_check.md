# C4 決済フロー 手動エミュレータ確認手順（W13→W14→W15→確定）

作成: 2026-07-07（C4 担当: 木幡）
本番 Firebase には一切書き込まず、ローカルエミュレータだけで
教材一覧 → 詳細 → 支払方法選択 → 確定（0円は完了画面まで）を通す手順。

## 使用ポート（firebase.dev.json で定義。チームの firebase.json は使わない※）

| サービス | ポート |
|---|---|
| Auth エミュレータ | 19099 |
| Firestore エミュレータ | 18080 |
| Functions エミュレータ | 15001 |
| Emulator UI（ブラウザでデータ確認） | 14000 |

※ チームの firebase.json は firestore が 8080 指定（WSL2 環境では別プロセスと競合）
かつ auth エミュレータ設定がないため、`--config firebase.dev.json` で別設定を使う。
`lib/payment/dev_emulator_main.dart` の接続先はこの表と一致させてある。

## 0. 前提（初回のみ確認）

- JDK 21（`java -version`）、firebase CLI ログイン済み
- functions をビルドしておく（エミュレータは predeploy を実行しないため必須）:

```bash
cd ~/my-project/campus-info-share
npm --prefix functions run build
```

## 1. ターミナルA: エミュレータ起動（起動しっぱなしにする）

```bash
cd ~/my-project/campus-info-share
STRIPE_SECRET_KEY=sk_test_dummy STRIPE_WEBHOOK_SECRET=whsec_dummy \
  firebase emulators:start --config firebase.dev.json \
  --only functions,firestore,auth --project campus-info-share
```

「All emulators ready!」が出たらOK。
（STRIPE_* はダミー値。0円フローは Stripe を使わないので完走する。
実カードフローまで見たい場合だけ `sk_test_dummy` を Stripe の**テストキー**に差し替える）

## 2. ターミナルB: テストデータ投入（エミュレータ起動後に1回）

```bash
cd ~/my-project/campus-info-share
NODE_PATH=./functions/node_modules node tool/seed_emulator_items.cjs
```

`seeded: items 2 件` と出れば成功（有償1500円 + 0円の2件）。
エミュレータのデータはメモリ上のみ。**エミュレータを再起動したら再実行**すること。

## 3. ターミナルC: アプリ起動

```bash
cd ~/my-project/campus-info-share
flutter run -d chrome -t lib/payment/dev_emulator_main.dart
```

ポート指定は不要（flutter が空きポートを自動選択。エミュレータとは衝突しない）。
起動時に自動で匿名ログインし、W13 教材一覧が開く。

## 4. ブラウザでの確認手順

1. **W13 一覧**: 教材が2件表示される。0円の「物理学Iの過去問プリント（無料）」に緑の「無料」バッジ
2. 0円の教材をタップ → **W14 詳細**（説明・「販売中」チップ・「無料で譲り受ける」ボタン）
3. 「無料で譲り受ける」→ **確認ダイアログ**が出る →「進む」
4. **W15 支払方法選択**（0円なので支払方法は出ず、案内文のみ）→「無料で譲り受ける（確定）」
5. **完了画面「譲渡が完了しました」**が出れば一気通貫成功
6. 「一覧へ戻る」→ W13 で無料教材が**消えている**（sold になり on_sale 一覧から外れた）
7. データ確認（任意）: http://localhost:14000 の Firestore タブで
   `items/demo_free_1` が `status: sold`、`transactions/free_demo_free_1` が `status: paid, amount: 0`

### 有償教材（線形代数 ¥1500）の挙動

- ダミー鍵のままだと: W15「支払い方法を確定」→ Stripe 連携で失敗 →
  エラー SnackBar が出て **W14 に差し戻される**（これ自体が
  在庫ロック → 失敗 → ロック解除ロールバックの動作確認になる。
  Emulator UI で `demo_paid_1` が on_sale に戻っていることも見られる）
- Stripe テストキーを設定した場合: カード入力画面（プレースホルダ）まで進み、
  金額と決済IDが表示される＝clientSecret 受領まで成功

## 5. 終了

ターミナルA・Cでそれぞれ Ctrl+C（エミュレータのデータは破棄される）。

## トラブルシュート

- `port taken` → `ss -tlnp | grep -E '18080|15001|19099|14000'` で占有プロセスを確認
- functions が読み込まれない → 手順0のビルドを忘れていないか
- 一覧が空 → 手順2のシードを忘れていないか（エミュレータ再起動後は再投入）
