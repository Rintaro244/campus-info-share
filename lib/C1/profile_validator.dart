// lib/C1/profile_validator.dart

class ProfileValidator {
  /// ユーザー名の入力値が正しいか判定するメソッド（1文字以上20文字以内）
  static bool validateUserName(String name) {
    if (name.isEmpty) {
      return false;
    }
    if (name.length > 20) {
      return false;
    }
    return true;
  }
}