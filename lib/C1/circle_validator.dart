// lib/C1/circle_validator.dart

class CircleValidator {
  /// サークル投稿の入力値が正しいか判定するメソッド
  static bool validateInput(String name, String description) {
    // 必須入力チェック
    if (name.isEmpty || description.isEmpty) {
      return false; // 空ならエラー
    }
    
    // 文字数上限チェック (団体名は30文字、紹介文は800文字まで)
    if (name.length > 30) {
      return false; // 30文字を超えたらエラー
    }
    if (description.length > 800) {
      return false; // 800文字を超えたらエラー
    }

    return true; // 全てクリアしたら成功
  }
}