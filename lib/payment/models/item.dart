/// 学内情報共有システム — C4 取引・決済処理部
/// 教材モデル（items コレクション。表示・出品の共通モデル）
///
/// スキーマの確定値は functions/src/constants.ts の ITEM_FIELDS。
/// 旧 C1/C3 の MarketModel（products コレクション）を本モデルへ統合した。
/// - userId  → sellerId に統一
/// - imageUrl(単一) → imageUrls(List) に統一（今後 Storage 対応前提）
/// - campus / condition を追加
/// title / description / price は既存ドキュメントに存在しないことがあるため
/// 読み取りは必ず null 安全に行う（表示は displayTitle 等のフォールバックを使う）。
library;

/// item.status の確定値（constants.ts の ITEM_STATUS と一致させること）。
class ItemStatus {
  static const String onSale = 'on_sale';
  static const String pending = 'pending';
  static const String sold = 'sold';

  const ItemStatus._();
}

/// 教材の表示用モデル。取引ロジック（M2/M3）はこのモデルに依存しない。
class Item {
  final String listingId;

  /// 教材タイトル（未設定のドキュメントでは null。表示は displayTitle を使う）。
  final String? title;
  final String? description;

  /// 正規価格（円・整数）。未設定・型不正なら null（購入不可として扱う）。
  final int? price;
  final String status;

  /// 出品者 uid（旧 MarketModel.userId を統合）。
  final String? sellerId;

  /// 購入者 uid（fulfill 時に Admin SDK が書き込む）。表示用に読むだけ。
  final String? buyerId;

  /// 受け渡し希望キャンパス（豊洲 / 大宮 / 両方 など）。
  final String? campus;

  /// 商品状態（新品同様 / 目立った傷や汚れなし など）。
  final String? condition;

  /// 教材写真（Firebase Storage URL）。旧 imageUrl(単一) を List に統一。
  final List<String> imageUrls;

  const Item({
    required this.listingId,
    this.title,
    this.description,
    this.price,
    required this.status,
    this.sellerId,
    this.buyerId,
    this.campus,
    this.condition,
    this.imageUrls = const [],
  });

  factory Item.fromMap(Map<String, dynamic> data, String id) {
    final price = data['price'];
    return Item(
      listingId: id,
      title: data['title'] as String?,
      description: data['description'] as String?,
      price: price is int ? price : null,
      status: data['status'] as String? ?? '',
      sellerId: data['sellerId'] as String?,
      buyerId: data['buyerId'] as String?,
      campus: data['campus'] as String?,
      condition: data['condition'] as String?,
      imageUrls: _readImageUrls(data),
    );
  }

  /// imageUrls(List) を読む。旧スキーマの imageUrl(単一String) しか無い
  /// ドキュメントは 1 要素の List として扱う（移行期の後方互換）。
  static List<String> _readImageUrls(Map<String, dynamic> data) {
    final list = data['imageUrls'];
    if (list is List) {
      return list.whereType<String>().toList();
    }
    final single = data['imageUrl'];
    if (single is String && single.isNotEmpty) return [single];
    return const [];
  }

  /// 出品（create）時に items へ書き込むマップ。
  /// title / price は呼び出し側（出品画面 + MarketValidator）で
  /// 検証済みの非 null 値であることを前提とする。
  /// buyerId は含めない（未設定 = 買い手なしで出品）。
  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'price': price,
      'status': status,
      'sellerId': sellerId,
      'campus': campus,
      'condition': condition,
      'imageUrls': imageUrls,
    };
  }

  /// 一覧・詳細に出すタイトル。title 未設定でも落ちないようフォールバックする。
  String get displayTitle {
    final t = title;
    if (t != null && t.trim().isNotEmpty) return t;
    return '教材 (ID: $listingId)';
  }

  bool get isOnSale => status == ItemStatus.onSale;

  /// 0円（無料譲渡）対象か。
  bool get isFree => price == 0;

  /// 購入ボタンを活性にできるか（販売中かつ価格情報が正常）。
  bool get canPurchase => isOnSale && price != null;
}
