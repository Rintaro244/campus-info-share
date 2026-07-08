// test/market_validator_test.dart

import 'package:flutter_test/flutter_test.dart';
// 💡 ご自身のプロジェクト名に合わせて変更してください
import 'package:student_information_1/C1/market_validator.dart';

void main() {
  group('C1 M6 教材取引モジュール 入力チェック単体テスト (境界値分析)', () {
    
    // --- 商品名 (title) の境界値 ---
    test('商品名が0文字の場合は false となること', () {
      final result = MarketValidator.validateItem(title: '', priceStr: '1000', description: '正常な説明文');
      expect(result, isFalse);
    });

    test('商品名が1文字の場合は true となること', () {
      final result = MarketValidator.validateItem(title: 'あ', priceStr: '1000', description: '正常な説明文');
      expect(result, isTrue);
    });

    test('商品名が40文字の場合は true となること', () {
      final result = MarketValidator.validateItem(title: 'あ' * 40, priceStr: '1000', description: '正常な説明文');
      expect(result, isTrue);
    });

    test('商品名が41文字の場合は false となること', () {
      final result = MarketValidator.validateItem(title: 'あ' * 41, priceStr: '1000', description: '正常な説明文');
      expect(result, isFalse);
    });

    // --- 価格 (price) の境界値 ---
    test('価格がマイナス（-1円）の場合は false となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '-1', description: '正常な説明文');
      expect(result, isFalse);
    });

    test('価格が0円（無料譲渡）の場合は true となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '0', description: '正常な説明文');
      expect(result, isTrue);
    });

    test('価格が100000円（最大値）の場合は true となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '100000', description: '正常な説明文');
      expect(result, isTrue);
    });

    test('価格が100001円（最大値+1）の場合は false となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '100001', description: '正常な説明文');
      expect(result, isFalse);
    });

    test('価格に数値以外の文字列が入力された場合は false となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '千円', description: '正常な説明文');
      expect(result, isFalse);
    });

    // --- 商品説明 (description) の境界値 ---
    test('商品説明が0文字の場合は false となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '1000', description: '');
      expect(result, isFalse);
    });

    test('商品説明が1文字の場合は true となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '1000', description: 'あ');
      expect(result, isTrue);
    });

    test('商品説明が1000文字の場合は true となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '1000', description: 'あ' * 1000);
      expect(result, isTrue);
    });

    test('商品説明が1001文字の場合は false となること', () {
      final result = MarketValidator.validateItem(title: '正常な商品名', priceStr: '1000', description: 'あ' * 1001);
      expect(result, isFalse);
    });
  });
}