// test/profile_validator_test.dart

import 'package:flutter_test/flutter_test.dart';
// 💡 C1 の中にある validator をインポートします
import 'package:student_information_1/C1/profile_validator.dart';

void main() {
  group('C1 プロフィールUIモジュール 入力チェック関数の単体テスト (境界値分析)', () {
    
    test('ユーザー名が0文字（未入力）の場合は false となること', () {
      final result = ProfileValidator.validateUserName('');
      expect(result, isFalse);
    });

    test('ユーザー名が1文字（最小値）の場合は true となること', () {
      final result = ProfileValidator.validateUserName('あ');
      expect(result, isTrue);
    });

    test('ユーザー名が20文字（最大値）の場合は true となること', () {
      final name20 = 'あ' * 20;
      final result = ProfileValidator.validateUserName(name20);
      expect(result, isTrue);
    });

    test('ユーザー名が21文字（最大値+1）の場合は false となること', () {
      final name21 = 'あ' * 21;
      final result = ProfileValidator.validateUserName(name21);
      expect(result, isFalse);
    });
  });
}