import 'package:flutter_test/flutter_test.dart';
// 💡 ご自身のプロジェクト名（pubspec.yamlのnameに書かれている名前）に合わせて書き換えてください
import 'package:student_information_1/C3/circle_manager.dart'; 

void main() {
  group('CircleManager 単体テスト', () {
    late CircleManager circleManager;

    // 各テストケースが実行される前に、毎回CircleManagerを初期化する
    setUp(() {
      circleManager = CircleManager();
    });

    // テスト1: 正常系（正しく入力したら登録できるか）
    test('【正常系】正しい入力値であれば登録に成功（true）すること', () async {
      final result = await circleManager.registerCircle(
        name: 'プログラミング研究会',
        campus: '豊洲',
        category: '文化系',
        description: 'みんなで楽しくアプリ開発を学ぶサークルです！',
      );
      
      // 結果が true であることを検証
      expect(result, isTrue);
    });

    // テスト2: 異常系（未入力エラーのチェック）
    test('【異常系】団体名が空のときは登録に失敗（false）すること', () async {
      final result = await circleManager.registerCircle(
        name: '', // あえて空っぽにする
        campus: '大宮',
        category: '運動系',
        description: '紹介文だけはある状態',
      );
      
      // 結果が false であることを検証
      expect(result, isFalse);
    });

    // テスト3: 異常系（文字数オーバーのチェック）
    test('【異常系】団体名が30文字を超えているときは登録に失敗（false）すること', () async {
      final longName = 'あ' * 31; // 「あ」を31文字連続させた文字列
      
      final result = await circleManager.registerCircle(
        name: longName,
        campus: '両方',
        category: 'その他',
        description: '紹介文は正常です。',
      );
      
      // 結果が false であることを検証
      expect(result, isFalse);
    });
  });
}