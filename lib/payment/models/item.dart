/// 学内情報共有システム — C4 取引・決済処理部
/// UI 表示用の教材モデル（items コレクションの読み取りビュー）
///
/// スキーマの確定値は functions/src/constants.ts の ITEM_FIELDS。
/// title / description は将来の出品機能が書き込む前提の確定フィールドだが、
/// 既存ドキュメントには存在しないことがあるため必ず null 安全に読む。
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
  final String? sellerId;

  /// 将来の Storage 連携用（現状は常に空でプレースホルダ表示）。
  final List<String> imageUrls;

  const Item({
    required this.listingId,
    this.title,
    this.description,
    this.price,
    required this.status,
    this.sellerId,
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
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
    );
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
