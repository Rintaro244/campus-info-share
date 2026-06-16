import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// 💡 ご自身のプロジェクト名に書き換えてください
import 'package:student_information_1/C1/circle_search_screen.dart';
import 'package:student_information_1/C1/circle_post_screen.dart';

void main() {
  group('C1 サークルUIモジュール 画面単体テスト', () {
    
    // テスト1: 検索画面が正しく表示され、初期データがあるか
    testWidgets('【検索画面】初期表示でタイトルとサークル名が表示されていること', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CircleSearchScreen()));

      expect(find.text('サークル・部活動検索'), findsOneWidget);
      // ドロップダウン化して新しくなった「キャンパス」「カテゴリ」のラベルがあるかもチェック
      expect(find.text('キャンパス'), findsOneWidget);
      expect(find.text('カテゴリ'), findsOneWidget);
    });

    // テスト2: 存在しないキーワードを入れた時に0件エラーが出るか
    testWidgets('【検索画面】存在しないサークル名を検索した際、0件メッセージが表示されること', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CircleSearchScreen()));

      // 最初のTextField（キーワード入力欄）に文字を入力
      await tester.enterText(find.byType(TextField).first, '存在しない謎のサークル名');
      await tester.pump(); // 画面の再描画

      expect(find.text('該当するデータが見つかりませんでした。'), findsOneWidget);
    });

// テスト3: 投稿画面で未入力のまま登録した時にエラーが出るか
    testWidgets('【投稿画面】未入力状態で登録ボタンを押すと、必須エラーのスナックバーが出ること', (WidgetTester tester) async {
      // 💡 画面側にScaffoldMessengerを仕込んだので、テスト側はこれだけでOK！
      await tester.pumpWidget(const MaterialApp(home: CirclePostScreen()));

      // 「この内容で登録する」ボタンを仮想タップ
      final submitButton = find.text('この内容で登録する');
      await tester.tap(submitButton);
      
      
      // スナックバーが表示されるのを少し待つ
      await tester.pump(const Duration(milliseconds: 300)); 

      // エラー文言が画面上に出現したかチェック
      expect(find.text('必須項目が入力されていません'), findsOneWidget);
    });
  });
}