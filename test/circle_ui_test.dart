import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// 💡 プロジェクト名に合わせて必要に応じて変更してください
import 'package:student_information_1/C1/circle_search_screen.dart';
import 'package:student_information_1/C1/circle_post_screen.dart';

void main() {
  group('C1 サークルUIモジュール 画面単体テスト (完全踏破版)', () {
    
    // ==========================================
    // 🔍 CircleSearchScreen (検索画面) のテスト
    // ==========================================

    testWidgets('【検索画面】初期表示と0件検索のテスト', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CircleSearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('サークル・部活動検索'), findsOneWidget);

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '存在しない謎のサークル名');
      await tester.pumpAndSettle();

      expect(find.text('該当するデータが見つかりませんでした。'), findsOneWidget);
    });

    testWidgets('【検索画面】ドロップダウンの変更とFAB（＋ボタン）タップのテスト', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CircleSearchScreen()));
      await tester.pumpAndSettle();

      final campusDropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(campusDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('豊洲').last);
      await tester.pumpAndSettle();

      final categoryDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('運動系').last);
      await tester.pumpAndSettle();

      if (find.text('芝浦ストリートダンス部').evaluate().isNotEmpty) {
        await tester.tap(find.text('芝浦ストリートダンス部').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      final fab = find.byType(FloatingActionButton);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('サークル・部活動登録'), findsOneWidget);
    });


    // ==========================================
    // 📝 CirclePostScreen (投稿画面) のテスト
    // ==========================================
    
    // 💡 Navigator.pop() 呼び出し時にテストがクラッシュするのを防ぐためのラップ用ウィジェット
    Widget createPostScreenTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CirclePostScreen()),
              ),
              child: const Text('GoToPost'),
            ),
          ),
        ),
      );
    }

    testWidgets('【投稿画面】初期表示と左上戻るボタンのテスト（カバレッジ回収）', (WidgetTester tester) async {
      await tester.pumpWidget(createPostScreenTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('GoToPost'));
      await tester.pumpAndSettle();

      expect(find.text('サークル・部活動登録'), findsOneWidget);

      // 左上の戻るアイコンボタンをタップ（Navigator.popのルートを網羅）
      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // 安全に元の画面に戻れたか確認
      expect(find.text('GoToPost'), findsOneWidget);
    });

    testWidgets('【投稿画面】未入力エラーのテスト', (WidgetTester tester) async {
      await tester.pumpWidget(createPostScreenTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('GoToPost'));
      await tester.pumpAndSettle();

      final submitButton = find.text('この内容で登録する');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); 

      expect(find.text('必須項目が入力されていません'), findsOneWidget);
    });

    testWidgets('【投稿画面】画像選択のON/OFFとスイッチのON/OFFのテスト（カバレッジ回収）', (WidgetTester tester) async {
      await tester.pumpWidget(createPostScreenTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('GoToPost'));
      await tester.pumpAndSettle();

      // 💡 ドロップダウンに邪魔されないよう、maxLength属性からテキストフィールドを厳密に一本釣りする
      final nameField = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 30);
      final descField = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 800);

      await tester.enterText(nameField, 'テストサークル');
      await tester.enterText(descField, 'テストの紹介文文面です。');
      await tester.pumpAndSettle();

      // 1. 画像領域をタップしてONにする
      await tester.ensureVisible(find.text('画像をアップロード (タップして選択)'));
      await tester.tap(find.text('画像をアップロード (タップして選択)'));
      await tester.pumpAndSettle();
      expect(find.text('画像が選択されています（タップで解除）'), findsOneWidget);

      // 2. スイッチをパチパチ切り替える（網羅率のため）
      final switchWidget = find.byType(Switch);
      await tester.ensureVisible(switchWidget);
      await tester.tap(switchWidget); // ON
      await tester.pumpAndSettle();
      await tester.tap(switchWidget); // OFF
      await tester.pumpAndSettle();
      await tester.tap(switchWidget); // もう一回ON（サイズエラーを出すため）
      await tester.pumpAndSettle();

      // 3. 登録ボタンを押す
      final submitButton = find.text('この内容で登録する');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ファイルサイズが大きすぎます。1MB以下のファイルを選択してください。'), findsOneWidget);

      // 4. 画像領域をもう一度タップして、選択を「解除」する（網羅率のため）
      await tester.ensureVisible(find.text('画像が選択されています（タップで解除）'));
      await tester.tap(find.text('画像が選択されています（タップで解除）'));
      await tester.pumpAndSettle();
      expect(find.text('画像をアップロード (タップして選択)'), findsOneWidget);
    });

    testWidgets('【投稿画面】正常入力で登録完了のテスト（カバレッジ100%達成）', (WidgetTester tester) async {
      await tester.pumpWidget(createPostScreenTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('GoToPost'));
      await tester.pumpAndSettle();

      // 💡 厳密に一本釣りして入力
      final nameField = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 30);
      final descField = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 800);

      await tester.enterText(nameField, 'テストサークル');
      
      // ドロップダウンを変更
      final campusDropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(campusDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('大宮').last);
      await tester.pumpAndSettle();

      final categoryDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('文化系').last);
      await tester.pumpAndSettle();

      await tester.enterText(descField, '正常なテスト用紹介文です。');
      await tester.pumpAndSettle();

      // 登録ボタンを押す
      final submitButton = find.text('この内容で登録する');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      
      // 💡 ボタンを押すと同時にpop（画面閉じる）が走るため、一きに画面が閉じるのを待ちます
      await tester.pumpAndSettle();

      // 🔍 【ここを修正】登録画面のタイトルが「消えた（findsNothing）」ことを確認
      expect(find.text('サークル・部活動登録'), findsNothing);
      
      // 元のダミー画面（GoToPostボタン）に安全に戻ってきたことを確認
      expect(find.text('GoToPost'), findsOneWidget);
    });
  });
}