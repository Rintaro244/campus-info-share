// test/circle_validator_test.dart

import 'package:flutter_test/flutter_test.dart';
// 💡 ご自身のプロジェクト名に合わせて変更してください
import 'package:student_information_1/C1/circle_validator.dart';

void main() {
  group('C1 M4 入力チェック関数の単体テスト (同値分割・境界値分析)', () {
    
    // --- 団体名 (name) の境界値分析 ---

    test('団体名が0文字（未入力）の場合は false となること', () {
      final result = CircleValidator.validateInput('', '正常な紹介文');
      expect(result, isFalse);
    });

    test('団体名が1文字（最小値）の場合は true となること', () {
      final result = CircleValidator.validateInput('あ', '正常な紹介文');
      expect(result, isTrue);
    });

    test('団体名が30文字（最大値）の場合は true となること', () {
      final name30 = 'あ' * 30;
      final result = CircleValidator.validateInput(name30, '正常な紹介文');
      expect(result, isTrue);
    });

    test('団体名が31文字（最大値+1）の場合は false となること', () {
      final name31 = 'あ' * 31;
      final result = CircleValidator.validateInput(name31, '正常な紹介文');
      expect(result, isFalse);
    });

    // --- 紹介文 (description) の境界値分析 ---

    test('紹介文が0文字（未入力）の場合は false となること', () {
      final result = CircleValidator.validateInput('正常な団体名', '');
      expect(result, isFalse);
    });

    test('紹介文が1文字（最小値）の場合は true となること', () {
      final result = CircleValidator.validateInput('正常な団体名', 'あ');
      expect(result, isTrue);
    });

    test('紹介文が800文字（最大値）の場合は true となること', () {
      final desc800 = 'あ' * 800;
      final result = CircleValidator.validateInput('正常な団体名', desc800);
      expect(result, isTrue);
    });

    test('紹介文が801文字（最大値+1）の場合は false となること', () {
      final desc801 = 'あ' * 801;
      final result = CircleValidator.validateInput('正常な団体名', desc801);
      expect(result, isFalse);
    });
  });
}