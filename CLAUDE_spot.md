# 学内情報共有システム（9班）

芝浦工業大学の学生向け情報共有アプリ
詳細は `docs/外部設計書.pdf` と `docs/要求仕様書.pdf` と `docs/内部設計書.pdf` を参照。

> ⚠ **本ファイルは内部設計書 Ver.1.2 に準拠**。画面番号・プログラム上の画面名・エラー番号は内部設計書を正とする。
> 過去に旧番号（W14〜W16）で実装していた箇所は、本ファイルの番号（W16〜W18）に揃えること。

---

## 技術スタック

| 用途 | 技術 |
|------|------|
| フロントエンド | Flutter (Stable Channel) / Dart |
| バックエンド | Firebase Cloud Functions / TypeScript (ES2020以降) |
| DB | Cloud Firestore |
| ストレージ | Firebase Storage |
| 認証 | Firebase Authentication (MFA: TOTP) |
| 地図 | Google Maps API |
| 決済 | Stripe API |

---

## アーキテクチャ方針

**Repositoryパターン**を採用。C5（外部連携・データアクセス処理部）の各クラスは
「単一の外部サービスとの通信に特化する」方針。
複数クラスを連携させる調整役は上位のC2/C3/C4（業務ロジック層）が担う。

```
C1 UI処理部（Flutter Widget）
  ↓
C2 認証処理部 / C3 情報管理部 / C4 取引・決済処理部
  ↓
C5 外部連携・データアクセス処理部（Repositoryクラス群）
  ↓
Firebase / Google Maps / Stripe
```

### C5 クラス一覧（全体）

| クラス | 役割 | 連携先 | 実装言語 |
|--------|------|--------|---------|
| AuthRepository | 認証アクセス | Firebase Authentication | Dart |
| UserRepository | ユーザーデータCRUD | Cloud Firestore | Dart |
| PostRepository | 投稿データCRUD（スポット含む） | Cloud Firestore | Dart |
| ItemRepository | 教材出品・購入・売却CRUD | Cloud Firestore | Dart |
| NotificationRepository | 通知データCRUD | Cloud Firestore | Dart |
| StorageRepository | 画像アップロード・取得・削除 | Firebase Storage | Dart |
| PaymentGateway | Stripe決済実行 | Stripe API | **TypeScript（Cloud Functions）** |
| MapApiClient | 地図・ジオコーディング | Google Maps API | Dart |

### C5 クラス間の依存（3つのみ）

- `PostRepository` → `StorageRepository`（投稿に画像が含まれる場合）
- `ItemRepository` → `StorageRepository`（教材出品時の商品画像）
- `NotificationRepository` → `PostRepository`（通知から元投稿を取得する際）

---

## 外部変数一覧（システム全体で共有）

| 外部変数名 | 型 | 用途 | 利用範囲 |
|-----------|-----|------|---------|
| c_session_uid | String | 現在ログイン中のユーザ識別ID。プロフィール表示や投稿・購入アクションのユーザ紐付けに常時利用。ログアウト時に破棄。 | システム全体 |
| c_selected_campus | String | UI上で選択中のキャンパス絞り込み条件（豊洲／大宮等）。講義(W5)・サークル(W7)・スポット検索(W16)で画面を切り替えても同一キャンパスの情報を維持するために利用。 | C1 (UI処理部) |
| c_pending_item_id | String | 購入対象の教材ID。教材詳細(W14)→支払方法選択(W15)へ遷移する際に決済対象を一時的に引き継ぐ。購入完了時にクリア。 | C1 / C4 |
| c_time | DateTime | クライアント側現在時刻。ヘッダー表示・投稿タイムスタンプ付与の基準。 | システム全体 |

> 鈴木の担当画面（W16〜W18）では主に `c_session_uid`（投稿者・コメント投稿者の紐付け、未ログイン判定）と
> `c_selected_campus`（キャンパス絞り込みの維持）を参照する。

---

## 鈴木の担当範囲

- **画面**：W16「おすすめスポット 検索・一覧」、W17「おすすめスポット 投稿」、W18「おすすめスポット 詳細・コメント」
  - プログラム上の画面名：`spot_search` / `spot_post` / `spot_detail`
- **C5**：スポット機能に関連する3クラス
  - `PostRepository`（スポットデータCRUD）
  - `StorageRepository`（スポット画像のアップロード・取得・削除）
  - `MapApiClient`（地図表示・ジオコーディング）

---

## データ仕様

### F6 おすすめスポット情報（Cloud Firestore: `spots` コレクション）

> **確定事項**：スポットは `posts` の拡張ではなく **独立した `spots` コレクション**として持つ
> （`PostRepository._spotsCollection = 'spots'` で実装確定）。
> フィールド命名は **キャメルケースで統一**（`spotName`, `authorUid` 等。実装確定）。

| フィールド | 型 | 制約 | 説明 |
|-----------|-----|------|------|
| spotId | String | 主キー、UUID | スポット識別ID |
| spotName | String | 最大256バイト、必須 | スポット名 |
| campus | String | "豊洲" or "大宮"、必須 | 対象キャンパス |
| category | String | 必須 | カフェ/飲食店/勉強スペース等 |
| recommendPoint | String | 最大1024バイト（※班で確認中）、必須 | おすすめポイント |
| latitude | double | -90.0〜90.0 | 緯度 |
| longitude | double | -180.0〜180.0 | 経度 |
| imageUrls | List\<String\> | Firebase Storage URL | スポット画像URL群 |
| createdAt | DateTime | 自動付与 | 投稿日時 |
| authorUid | String | Firebase AuthのUID（= c_session_uid） | 投稿者ID |

#### F6 追加候補フィールド（実装が先行・**班で要確認**）

下記は内部設計書に記載がないが、実装側（`Spot` モデル）に先行して存在する項目。
**勝手に確定・削除はせず**、次回の班ミーティングで採否を諮ること。

| フィールド | 型 | 説明 | 備考 |
|-----------|-----|------|------|
| description | String | スポットの説明文 | recommendPoint との役割重複を要整理 |
| tags | List\<String\> | タグ（自由付与） | 検索・絞り込みに使うか要検討 |
| hours | String | 営業時間 | 表記フォーマット未定 |
| walkMinutes | int | キャンパスからの徒歩分数 | 算出方法（手入力か地図API）未定 |
| priceRange | String | 価格帯 | カテゴリとの関係を要整理 |
| averageRating | double | 平均星評価（F7集計値） | 集計タイミング（書込時/読込時）未定 |
| reviewCount | int | レビュー件数 | 同上 |

### F7 おすすめスポットコメント（`spots/{spotId}/reviews` サブコレクション）

| フィールド | 型 | 制約 | 説明 |
|-----------|-----|------|------|
| reviewId | String | 主キー | レビュー識別ID |
| spotId | String | 親ドキュメントのID | 対象スポットID |
| starRating | int | 1〜5、必須（スポットのみ） | 星評価 |
| comment | String | 最大512文字（文字数。UTF-8では最大約1536バイト相当） | コメント本文 |
| authorUid | String | Firebase AuthのUID（= c_session_uid） | 投稿者ID |
| createdAt | DateTime | 自動付与 | 投稿日時 |

> **文字数の数え方に注意**：Dartの `String.length` はUTF-16コード単位を返すため、絵文字や一部漢字（サロゲートペア）で
> 意図とズレる。512文字の判定は `characters` パッケージの `.characters.length`（書記素クラスタ単位）で行うこと。
>
> ⚠ **サーバー側バリデーション必須**：512文字制限はUI（`SpotDetailScreen` の `maxLength: 512`）だけでなく、
> **`PostRepository.addReview` 側でも必ず検証**すること。UI制限のみだと直接呼び出しで回避できてしまう。
> 超過時は `ValidationException` をスロー（W18 E5に対応）。

> **制限値の役割の違い（意図的な混在）**
> - スポット名・おすすめポイント → **バイト**指定（Firestoreのストレージ・インデックス制約を意識した内部バリデーション値）
> - コメント → **文字数**指定（W18 E5で「現在○○文字」とUIに直接表示するため）

### F1 アカウント情報（`users` コレクション）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| uid | String | Firebase AuthのUID（主キー） |
| userName | String | 最大256バイト |
| iconUrl | String | Firebase Storage URL |
| createdAt | DateTime | 作成日時 |

---

## 画面仕様（担当：W16〜W18）

### W16 おすすめスポット 検索・一覧画面（`spot_search`）

2段階構成：
- **W16-a**：キャンパス選択（豊洲 or 大宮）
- **W16-b**：スポット一覧（ListView.builderカード形式）

主要ウィジェット：`DropdownButton`（キャンパス切替）、`Card`（スポットカード）、
`FloatingActionButton`（W17へ遷移）、`BottomNavigationBar`（下部固定）

### W17 おすすめスポット 投稿画面（`spot_post`）

必須入力項目：画像・スポット名（最大256バイト）・キャンパス・カテゴリ・
おすすめポイント（最大1024バイト、※班で確認中）・位置情報（地図ピン）

主要ウィジェット：`TextField`、`ToggleButtons`（キャンパス選択）、
`DropdownButton`（カテゴリ）、`GoogleMap`（位置情報）、`ElevatedButton`（投稿）

### W18 おすすめスポット 詳細・コメント画面（`spot_detail`）

表示内容：スポット画像（PageView）・基本情報・地図（GoogleMap）・コメント一覧

主要ウィジェット：`PageView`（複数画像スワイプ）、`GoogleMap`、
`ListView.builder`（コメント）、`TextField` + `IconButton`（コメント入力・送信）

---

## 重要な実装制約

1. **画像は必ず1MB以下に圧縮してからアップロード**（要求仕様書4.1）
   - StorageRepository の `uploadImage` で自動圧縮を実装すること
   - 圧縮できない場合は `ImageCompressionException` をスロー（W17 E6に対応）

2. **APIキーは絶対にコミットしない**
   - `lib/secrets.dart` または `.env` に置く
   - これらのファイルは `.gitignore` に追加済みであること

3. **Firebaseのサービスアカウントファイルをコミット禁止**
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

4. **決済（Stripe）はクライアント側でAPIキーを使わない**
   - Flutter側はStripe SDKでトークン化のみ行う
   - 決済本処理はCloud Functions（TypeScript）の `PaymentGateway.executePayment` が担う

5. **レスポンシブ対応**（要求仕様書7章）
   - ブレークポイント：〜600px（スマホ）、600〜1200px（タブレット）、1200px〜（PC）
   - `MediaQuery` または `LayoutBuilder` で切り替え
   - スポット一覧のカード数：スマホ1列→タブレット2列→PC3〜4列

---

## エラー処理（担当：W16〜W18）

内部設計書のエラー番号（E1〜）に準拠する。

### W16 おすすめスポット 検索・一覧画面

| No | 入力エラーの内容 | エラー処理 |
|----|----------------|-----------|
| E1 | キャンパス選択後、該当キャンパスにスポットが0件 | 「このキャンパスにはまだスポットが登録されていません。投稿ボタンから最初のスポットを登録しませんか？」を表示し、投稿ボタンを強調表示 |
| E2 | Cloud Firestoreからのスポット一覧取得に失敗（ネットワーク不良等） | 「スポット情報を取得できませんでした。通信環境を確認してください」＋「再読み込み」ボタンを表示 |
| E3 | スポット画像（Firebase Storage）の読み込み失敗 | 該当カードにプレースホルダ画像を表示。アプリ動作は継続 |
| E4 | カテゴリ絞り込みで該当スポットが0件 | 「該当するスポットが見つかりませんでした。」＋絞り込み条件クリアボタンを表示 |
| E5 | お気に入り登録時、未ログイン状態（セッション切れ等） | 「ログインが必要です」を表示し、W1ログイン画面へ遷移 |

### W17 おすすめスポット 投稿画面

| No | 入力エラーの内容 | エラー処理 |
|----|----------------|-----------|
| E1 | スポット名が未入力で投稿ボタン押下 | 「スポット名を入力してください」を表示し、入力欄を赤枠で強調 |
| E2 | キャンパスが未選択で投稿ボタン押下 | 「キャンパスを選択してください」を表示 |
| E3 | カテゴリが未選択で投稿ボタン押下 | 「カテゴリを選択してください」を表示 |
| E4 | おすすめポイントが未入力で投稿ボタン押下 | 「おすすめポイントを入力してください」を表示 |
| E5 | 写真が未選択で投稿ボタン押下 | 「スポットの写真を1枚以上追加してください」を表示 |
| E6 | アップロード画像が容量制限(1MB)超過 | アプリ側で自動的に1MB以下に圧縮。圧縮不可なら「画像サイズが大きすぎます。別の画像を選択してください」を表示 |
| E7 | マップAPI連携でピン位置から住所/座標が取得できない | 「位置情報が取得できませんでした。地図上で再度ピンを立て直してください」を表示 |
| E8 | Firebase Storageへの画像アップロード失敗 | 「画像のアップロードに失敗しました。通信環境を確認して再度お試しください」を表示し、入力内容は保持 |
| E9 | Firestoreへのスポット情報保存失敗 | 「投稿に失敗しました。通信環境を確認して再度お試しください」を表示し、入力内容は保持 |

### W18 おすすめスポット 詳細・コメント画面

| No | 入力エラーの内容 | エラー処理 |
|----|----------------|-----------|
| E1 | スポット詳細データ取得失敗 | 「スポット情報を取得できませんでした。通信環境を確認してください」＋W16へ戻るボタンを表示 |
| E2 | スポット画像の読み込み失敗 | プレースホルダ画像を表示。アプリ動作は継続 |
| E3 | 地図の読み込み失敗（Map API連携エラー） | 地図エリアに「地図を読み込めませんでした」を表示し、住所テキストで代替 |
| E4 | コメント未入力で送信ボタン押下 | 送信ボタンを非活性化し、押下を無効化 |
| E5 | コメントが文字数制限(512文字)超過 | 入力欄下に「コメントは512文字以内で入力してください（現在○○文字）」を表示 |
| E6 | コメント送信時、Cloud Firestore保存失敗 | 「コメントの投稿に失敗しました。再度お試しください」を表示し、入力内容は保持 |
| E7 | コメント送信時、未ログイン状態（セッション切れ等） | 「ログインが必要です」を表示し、W1ログイン画面へ遷移 |
| E8 | コメント一覧取得失敗 | 「コメントを取得できませんでした」＋「再読み込み」ボタンを表示 |

> **設計書からの補正メモ**
> - W18 E1の戻り先は設計書原文では「W14へ戻る」だが、旧番号体系の誤りと判断しW16へ修正済み。
> - W18 E5の「512文字？」の疑問符は、F7仕様の512文字と一致するため確定値として扱う。

### Repository層の例外クラス（鈴木担当分）

実装時は以下の例外クラスを定義して使用する：

```dart
// データアクセス（スポット）
PostNotFoundException        // W18 E1
ValidationException          // W17 E1〜E5 / W18 E5
PermissionDeniedException

// ストレージ
StorageException             // W17 E8 / W16 E3・W18 E2（読み込み失敗）
ImageCompressionException    // W17 E6（圧縮不可）
UnsupportedFormatException

// ネットワーク・地図
NetworkException             // W16 E2 / W17 E9 / W18 E6・E8
QuotaExceededException
AddressNotFoundException      // W17 E7 / W18 E3（地図関連）
```

---

## プロジェクト構成（推奨）

```
lib/
├── main.dart
├── secrets.dart              # ⚠ .gitignore対象（コミット禁止）
├── models/
│   ├── spot.dart             # F6 スポット情報モデル
│   ├── spot_review.dart      # F7 スポットコメントモデル
│   └── user_profile.dart     # F1 ユーザー情報モデル（参照用・読み取り専用）
├── repositories/             # C5 Repositoryクラス（鈴木担当分のみ）
│   ├── post_repository.dart      # スポットデータCRUD
│   ├── storage_repository.dart   # スポット画像
│   └── map_api_client.dart       # 地図・ジオコーディング
├── features/
│   └── spot/                 # おすすめスポット機能（鈴木担当）
│       ├── spot_search_screen.dart   # W16 spot_search
│       ├── spot_post_screen.dart     # W17 spot_post
│       └── spot_detail_screen.dart   # W18 spot_detail
└── shared/
    └── exceptions.dart       # スポット機能で使う例外クラス
```

> 旧構成では `spot_list_screen.dart`（W14）等のファイル名だったが、
> 内部設計書のプログラム画面名（`spot_search` / `spot_post` / `spot_detail`）に合わせてリネームすること。

---

## ブランチ運用ルール

- `main`：常に動く状態を保つ。直接pushしない
- `feature/機能名`：各機能の開発ブランチ
- 作業完了後はPull Requestを出してmainにマージ

鈴木の担当ブランチ例：`feature/spot-search`、`feature/spot-post`、`feature/spot-detail`

---

## 参考ドキュメント（docs/フォルダ）

- `docs/外部設計書.pdf`：コンポーネント構成、画面仕様、データ仕様、インターフェース仕様
- `docs/要求仕様書.pdf`：ユースケース記述（スポット関連）、品質要件、設計制約
- `docs/内部設計書.pdf`：W16〜W18の画面詳細、モジュール構成図及びモジュール仕様（**本ファイルの正となる設計書**）

---

## 未確定事項（班で確認中）

- おすすめポイントの最大長（暫定1024バイト）
- F6追加候補フィールド（description / tags / hours / walkMinutes / priceRange / averageRating / reviewCount）の採否
  ※ 実装が先行している。データ仕様の「F6 追加候補フィールド」表を参照
- Google Maps APIキーの管理方法（クライアント側 or Cloud Functions経由）

### 確定済み（旧・未確定事項から移動）

- ~~スポット情報を `posts` 拡張にするか独立 `spots` にするか~~ → **独立 `spots` コレクションで確定**
- ~~フィールド命名規則（キャメル vs スネーク）~~ → **キャメルケースで確定**
