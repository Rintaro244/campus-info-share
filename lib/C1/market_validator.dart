// lib/C1/market_validator.dart

class MarketValidator {
  /// 商品名の上限文字数。画面の文字数カウンタと判定で同じ値を使う。
  static const int maxTitleLength = 40;

  /// 商品説明の上限文字数。
  static const int maxDescriptionLength = 1000;

  /// 価格の上限（円）。
  static const int maxPrice = 100000;

  /// 教材出品の入力値を判定するメソッド
  static bool validateItem({
    required String title,
    required String priceStr,
    required String description,
  }) {
    // 1. 必須入力チェック（空文字列はエラー）
    if (title.trim().isEmpty || priceStr.trim().isEmpty || description.trim().isEmpty) {
      return false;
    }

    // 2. 商品名の文字数チェック（1〜40文字）
    if (title.trim().length > maxTitleLength) {
      return false;
    }

    // 3. 価格の数値・範囲チェック（0〜100,000円）
    final price = int.tryParse(priceStr.trim());
    if (price == null || price < 0 || price > maxPrice) {
      return false;
    }

    // 4. 商品説明の文字数チェック（1〜1000文字）
    if (description.trim().length > maxDescriptionLength) {
      return false;
    }

    return true; // すべての条件をクリア
  }
}