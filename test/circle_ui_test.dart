import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_information_1/C1/circle_search_screen.dart';
import 'package:student_information_1/C1/circle_post_screen.dart';

void main() {
  group('C1 サークルUIモジュール 画面単体テスト (完全追従版)', () {
    
    // スナックバーとナビゲーションをテスト環境で安定させるための共通ファクトリ
    Widget createTestableWidget(Widget screen) {
      return MaterialApp(
        home: Scaffold(
          body: screen,
        ),
      );
    }

    // ==========================================
    // 🔍 CircleSearchScreen (検索画面) のテスト
    // ==========================================

    testWidgets('【検索画面】初期表示でタイトルとサークル名が表示されていること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CircleSearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('サークル・部活動検索'), findsOneWidget);
      expect(find.text('キャンパス'), findsOneWidget);
      expect(find.text('カテゴリ'), findsOneWidget);
    });

    testWidgets('【検索画面】存在しないサークル名を検索した際、0件メッセージが表示されること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CircleSearchScreen()));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '存在しない謎のサークル名');
      await tester.pumpAndSettle();

      expect(find.text('該当するデータが見つかりませんでした。'), findsOneWidget);
    });

    testWidgets('【検索画面】ドロップダウンを変更してキャンパスとカテゴリの絞り込みができること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CircleSearchScreen()));
      await tester.pumpAndSettle();

      // キャンパスのドロップダウンを開く
      final campusDropdown = find.byKey(const Key('campus_dropdown'));
      await tester.tap(campusDropdown);
      await tester.pumpAndSettle();
      // ドロップダウンメニュー内の「豊洲」を選択
      await tester.tap(find.text('豊洲').last);
      await tester.pumpAndSettle();

      // カテゴリのドロップダウンを開く
      final categoryDropdown = find.byKey(const Key('category_dropdown'));
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      // ドロップダウンメニュー内の「運動系」を選択
      await tester.tap(find.text('運動系').last);
      await tester.pumpAndSettle();

      // 絞り込まれた結果が表示されているか確認
      expect(find.text('芝浦ストリートダンス部'), findsOneWidget);
    });

    testWidgets('【検索画面】サークル項目をタップした際に詳細スナックバーが表示されること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CircleSearchScreen()));
      await tester.pumpAndSettle();

      // 「芝浦工大公式鉄道研究会」のテキストの要素をタップ
      await tester.tap(find.text('芝浦工大公式鉄道研究会'));
      // スナックバーが描画されるのを待つ
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('「芝浦工大公式鉄道研究会」の詳細画面へ（開発中）'), findsOneWidget);
    });


    // ==========================================
    // 📝 CirclePostScreen (投稿画面) のテスト
    // ==========================================

    testWidgets('【投稿画面】未入力状態で登録ボタンを押すと、必須エラーのスナックバーが出ること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CirclePostScreen()));
      await tester.pumpAndSettle();

      final submitButton = find.text('この内容で登録する');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); 

      expect(find.text('必須項目が入力されていません'), findsOneWidget);
    });

    testWidgets('【投稿画面】画像を選択し、テスト用スイッチをONにするとファイルサイズエラーが出ること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CirclePostScreen()));
      await tester.pumpAndSettle();

      // 正常に入力（必須チェック回避用）
      await tester.enterText(find.byType(TextField).first, 'テストサークル');
      await tester.enterText(find.byType(TextField).last, 'テストの紹介文文面です。');
      await tester.pumpAndSettle();

      // カバー画像領域のタップ
      await tester.tap(find.text('画像をアップロード (タップして選択)'));
      await tester.pumpAndSettle();

      // スイッチをONにする
      final switchWidget = find.byType(Switch);
      await tester.ensureVisible(switchWidget);
      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      // 登録する
      final submitButton = find.text('この内容で登録する');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ファイルサイズが大きすぎます。1MB以下のファイルを選択してください。'), findsOneWidget);
    });

    testWidgets('【投稿画面】正常に入力して登録ボタンを押すと、擬似登録が完了すること', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CirclePostScreen()));
      await tester.pumpAndSettle();

      // 1. 団体名
      await tester.enterText(find.byType(TextField).first, 'テストサークル');
      
      // 2. キャンパスドロップダウンを変更
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('大宮').last);
      await tester.pumpAndSettle();

      // 3. カテゴリドロップダウンを変更
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('文化系').last);
      await tester.pumpAndSettle();

      // 4. 紹介文
      await tester.enterText(find.byType(TextField).last, '正常なテスト用紹介文です。');
      await tester.pumpAndSettle();

      // 5. 登録ボタン
      final submitButton = find.text('この内容で登録する');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('「テストサークル」を登録しました（擬似処理）'), findsOneWidget);
    });
  });
}