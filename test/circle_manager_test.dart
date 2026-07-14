import 'package:flutter_test/flutter_test.dart';
// 💡 ご自身のプロジェクト名（pubspec.yamlのname）に合わせて書き換えてください
import 'package:student_information_1/C3/circle_manager.dart'; 

void main() {
  group('C3 サークル管理モジュール クラス単体テスト (境界値分析・網羅率100%)', () {
    late CircleManager circleManager;

    // 各テストケースが実行される前に、毎回CircleManagerとデータベースを初期化する
    setUp(() {
      circleManager = CircleManager();
    });

    // ==========================================
    // 📝 1. registerCircle (サークル登録) のテスト
    // ==========================================
    group('registerCircle 関数のテスト', () {
      
      // --- 団体名 (name) の境界値分析 ---
      test('【境界値】団体名が0文字（未入力）の場合はエラー（false）となること', () async {
        final result = await circleManager.registerCircle(
          name: '',
          campus: '豊洲',
          category: '文化系',
          description: '正常な紹介文',
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isFalse);
      });

      test('【境界値】団体名が1文字（最小値）の場合は正常登録（true）できること', () async {
        final result = await circleManager.registerCircle(
          name: 'あ',
          campus: '豊洲',
          category: '文化系',
          description: '正常な紹介文',
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isTrue);
      });

      test('【境界値】団体名が30文字（最大値）の場合は正常登録（true）できること', () async {
        final result = await circleManager.registerCircle(
          name: 'あ' * 30,
          campus: '豊洲',
          category: '文化系',
          description: '正常な紹介文',
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isTrue);
      });

      test('【境界値】団体名が31文字（最大値+1）の場合はエラー（false）となること', () async {
        final result = await circleManager.registerCircle(
          name: 'あ' * 31,
          campus: '豊洲',
          category: '文化系',
          description: '正常な紹介文',
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isFalse);
      });
      });

      // --- 紹介文 (description) の境界値分析 ---
      test('【境界値】紹介文が0文字（未入力）の場合はエラー（false）となること', () async {
        final result = await circleManager.registerCircle(
          name: '正常な団体名',
          campus: '豊洲',
          category: '文化系',
          description: '',
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isFalse);
      });

      test('【境界値】紹介文が1文字（最小値）の場合は正常登録（true）できること', () async {
        final result = await circleManager.registerCircle(
          name: '正常な団体名',
          campus: '豊洲',
          category: '文化系',
          description: 'あ',
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isTrue);
      });

      test('【境界値】紹介文が800文字（最大値）の場合は正常登録（true）できること', () async {
        final result = await circleManager.registerCircle(
          name: '正常な団体名',
          campus: '豊洲',
          category: '文化系',
          description: 'あ' * 800,
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isTrue);
      });

      test('【境界値】紹介文が801文字（最大値+1）の場合はエラー（false）となること', () async {
        final result = await circleManager.registerCircle(
          name: '正常な団体名',
          campus: '豊洲',
          category: '文化系',
          description: 'あ' * 801,
          userId: 'test_user_123', // 💡 userId を追加
        );
        expect(result, isFalse);
      });
    // ==========================================
    // 🔍 2. searchCircles (サークル検索) のテスト
    // ==========================================
    group('searchCircles 関数のテスト（分岐網羅）', () {
      
      test('【キーワード空】キーワードが空の場合は、全件が対象となること', () async {
        // campus='すべて', category='すべて' で全件取得の分岐を通す
        final results = await circleManager.searchCircles(
          keyword: '',
          campus: 'すべて',
          category: 'すべて',
        );
        // 初期データ3件すべてが返るはず
        expect(results.length, equals(3));
      });

      test('【キーワード名前に一致】団体名に含まれるキーワードで検索できること', () async {
        final results = await circleManager.searchCircles(
          keyword: '鉄道',
          campus: 'すべて',
          category: 'すべて',
        );
        expect(results.length, equals(1));
        expect(results.first.name, contains('鉄道'));
      });

      test('【キーワード名前に部分一致】サークル名の一部（後ろの文字など）で検索できること', () async {
        final results = await circleManager.searchCircles(
          keyword: 'C3',
          campus: 'すべて',
          category: 'すべて',
        );
        expect(results.length, equals(1));
        expect(results.first.name, contains('プログラミングサークルC3'));
      });

      test('【キャンパス一致】指定したキャンパスのサークルが取得できること', () async {
        // 大宮キャンパスを検索（鉄道は豊洲、テニスは大宮、C3は両方なので、テニスとC3の2件）
        final results = await circleManager.searchCircles(
          keyword: '',
          campus: '大宮',
          category: 'すべて',
        );
        expect(results.length, equals(2));
      });

      test('【カテゴリ一致】指定したカテゴリのサークルが取得できること', () async {
        // 運動系を検索（テニス部の1件がヒットするはず）
        final results = await circleManager.searchCircles(
          keyword: '',
          campus: 'すべて',
          category: '運動系',
        );
        expect(results.length, equals(1));
        expect(results.first.category, equals('運動系'));
      });

      test('【不一致ルート】どの条件にも合致しない場合は空のリストが返ること', () async {
        final results = await circleManager.searchCircles(
          keyword: '存在しないサークル名',
          campus: '豊洲',
          category: '運動系',
        );
        expect(results, isEmpty);
      });
    });
  });
}