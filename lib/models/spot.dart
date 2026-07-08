//おすすめスポット情報で扱うデータモデル
enum Campus {
  toyosu,
  omiya;

  String get label => switch (this) {
        Campus.toyosu => '豊洲',
        Campus.omiya => '大宮',
      };

  static Campus fromString(String value) => switch (value) {
        '豊洲' => Campus.toyosu,
        '大宮' => Campus.omiya,
        _ => throw ArgumentError('不明なキャンパス値: $value'),
      };

  // スポット投稿画面で地図の初期表示位置に使うキャンパスの代表座標
  double get defaultLatitude => switch (this) {
        Campus.toyosu => 35.660853,
        Campus.omiya => 35.951853,
      };

  double get defaultLongitude => switch (this) {
        Campus.toyosu => 139.795533,
        Campus.omiya => 139.654475,
      };
}

class Spot {
  final String spotId;
  final String spotName;
  final Campus campus;
  final String category;
  // W15「おすすめポイント」に対応（F6仕様に未記載のため班で要確認）
  final String? description;
  // 設備タグ（例: ["WiFi完備", "電源あり"]）
  final List<String> tags;
  // 営業時間（例: "10:00 ～ 20:00"）
  final String? hours;
  // 最寄りからの徒歩分数
  final int? walkMinutes;
  // 価格帯（例: "¥1,000"）
  final String? priceRange;
  // 平均星評価（レビュー追加時にトランザクションで更新）
  final double? averageRating;
  // レビュー件数（同上）
  final int? reviewCount;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final DateTime createdAt;
  final String authorUid;

  const Spot({
    required this.spotId,
    required this.spotName,
    required this.campus,
    required this.category,
    this.description,
    this.tags = const [],
    this.hours,
    this.walkMinutes,
    this.priceRange,
    this.averageRating,
    this.reviewCount,
    this.latitude,
    this.longitude,
    required this.imageUrls,
    required this.createdAt,
    required this.authorUid,
  });

  // Firestoreから取得したデータを変換する際はRepositoryでTimestamp→DateTimeに変換してから渡す
  factory Spot.fromMap(Map<String, dynamic> data, String id) {
    return Spot(
      spotId: id,
      spotName: data['spotName'] as String,
      campus: Campus.fromString(data['campus'] as String),
      category: data['category'] as String,
      description: data['description'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      hours: data['hours'] as String?,
      walkMinutes: data['walkMinutes'] as int?,
      priceRange: data['priceRange'] as String?,
      averageRating: (data['averageRating'] as num?)?.toDouble(),
      reviewCount: data['reviewCount'] as int?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      createdAt: data['createdAt'] as DateTime,
      authorUid: data['authorUid'] as String,
    );
  }

  // RepositoryでcreatedAtをFieldValue.serverTimestamp()に差し替えてからFirestoreに書き込む
  Map<String, dynamic> toMap() {
    return {
      'spotName': spotName,
      'campus': campus.label,
      'category': category,
      'description': description,
      'tags': tags,
      'hours': hours,
      'walkMinutes': walkMinutes,
      'priceRange': priceRange,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'createdAt': createdAt,
      'authorUid': authorUid,
    };
  }

  Spot copyWith({
    String? spotId,
    String? spotName,
    Campus? campus,
    String? category,
    String? description,
    List<String>? tags,
    String? hours,
    int? walkMinutes,
    String? priceRange,
    double? averageRating,
    int? reviewCount,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    DateTime? createdAt,
    String? authorUid,
  }) {
    return Spot(
      spotId: spotId ?? this.spotId,
      spotName: spotName ?? this.spotName,
      campus: campus ?? this.campus,
      category: category ?? this.category,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      hours: hours ?? this.hours,
      walkMinutes: walkMinutes ?? this.walkMinutes,
      priceRange: priceRange ?? this.priceRange,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      authorUid: authorUid ?? this.authorUid,
    );
  }
}
