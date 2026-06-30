# Firestore Security Rules テスト

`firestore.rules`（リポジトリルート）の items ルールを `@firebase/rules-unit-testing`
＋ Firestore エミュレータで検証する。

## 前提
- **Java ランタイムが必要**（Firestore エミュレータが JVM で動くため）。未インストールだと
  `firebase emulators:exec` が失敗する。
- Node.js 20+, firebase-tools（リポジトリの firebase CLI でよい）。

## セットアップ & 実行
```bash
cd firestore-tests
npm install

# エミュレータを自動起動してテスト（推奨）
npm run test:emulator

# すでに別ターミナルで `firebase emulators:start --only firestore` 済みなら
npm test
```

`firebase.json` の `emulators.firestore.port`（8080）と `rules.test.js` の接続先ポートは一致させてある。
projectId は `demo-` プレフィックスのデモ用（実プロジェクトに接続しない）。

## テストケース
1. read は未ログインでも許可
2. 正常ロック（on_sale → pending + 自分の buyerId）は許可
3. 未ログインのロックは拒否
4. price 変更は拒否
5. クライアントからの直接 sold 変更は拒否
6. 他人の uid を buyerId にしたロックは拒否
7. ロック保持者本人の unlock は許可
8. 非保持者の unlock は拒否
9. create / delete は拒否
