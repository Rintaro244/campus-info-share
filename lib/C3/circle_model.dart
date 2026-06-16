// 💡 C3 M5: サークル・部活動のデータを管理するモデルクラス
class CircleModel {
  final String id;          // ドキュメントID
  final String name;        // 団体名（最大30文字）
  final String campus;      // 活動キャンパス（豊洲 / 大宮 / 両方）
  final String category;    // カテゴリ（運動系 / 文化系 / その他）
  final String description; // 紹介文（最大800文字）
  final String? imageUrl;   // カバー画像のURL（任意）

  CircleModel({
    required this.id,
    required this.name,
    required this.campus,
    required this.category,
    required this.description,
    this.imageUrl,
  });

  // 💡 Firebase (Map型データ) から受け取ったデータを、このクラスの形に変換する処理
  factory CircleModel.fromMap(String docId, Map<String, dynamic> map) {
    return CircleModel(
      id: docId,
      name: map['name'] ?? '',
      campus: map['campus'] ?? '豊洲',
      category: map['category'] ?? 'その他',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }

  // 💡 逆に、Firebaseに保存するためにこのクラスを Map型 に変換する処理
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'campus': campus,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}