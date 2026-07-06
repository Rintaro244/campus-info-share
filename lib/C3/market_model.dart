// lib/C3/market_model.dart

class MarketModel {
  final String id;
  final String title;       // 教科書名・アイテム名
  final int price;          // 価格
  final String campus;      // 受け渡し希望キャンパス
  final String condition;   // 状態（新品同様、目立った傷なし、など）
  final String description; // 詳細説明
  final String? imageUrl;   // 💡 追加：商品の画像URL
  final String userId;      // 💡 追加：出品者のユーザーID

  MarketModel({
    required this.id,
    required this.title,
    required this.price,
    required this.campus,
    required this.condition,
    required this.description,
    this.imageUrl, // 💡
    required this.userId, // 💡
  });

  factory MarketModel.fromMap(String docId, Map<String, dynamic> map) {
    return MarketModel(
      id: docId,
      title: map['title'] ?? '',
      price: map['price'] ?? 0,
      campus: map['campus'] ?? '豊洲',
      condition: map['condition'] ?? '目立った傷や汚れなし',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'], // 💡
      userId: map['userId'] ?? '', // 💡
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'price': price,
      'campus': campus,
      'condition': condition,
      'description': description,
      'imageUrl': imageUrl, // 💡
      'userId': userId, // 💡
    };
  }
}