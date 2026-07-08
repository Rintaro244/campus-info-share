/// C4 チャット画面の widget テスト。
/// ChatRepository を implements した Fake を注入し、StreamBuilder による表示と
/// 送信動作（sendMessage 呼び出し・入力クリア・空送信の抑止）を検証する。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_information_1/payment/models/chat_message.dart';
import 'package:student_information_1/payment/services/chat_repository.dart';
import 'package:student_information_1/payment/ui/screens/chat_screen.dart';

/// 記録用の送信引数。
class SentMessage {
  final String roomId;
  final String senderId;
  final String text;
  const SentMessage(this.roomId, this.senderId, this.text);
}

class FakeChatRepository implements ChatRepository {
  final StreamController<List<ChatMessage>> _controller =
      StreamController<List<ChatMessage>>.broadcast();
  final List<SentMessage> sent = [];

  void emit(List<ChatMessage> messages) => _controller.add(messages);

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) => _controller.stream;

  @override
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > ChatRepository.maxTextLength) return;
    sent.add(SentMessage(roomId, senderId, trimmed));
  }

  void dispose() => _controller.close();
}

Widget _app(FakeChatRepository repo) {
  return MaterialApp(
    home: ChatScreen(
      roomId: 'free_item1',
      currentUid: 'buyer1',
      repository: repo,
    ),
  );
}

void main() {
  late FakeChatRepository repo;

  setUp(() => repo = FakeChatRepository());
  tearDown(() => repo.dispose());

  testWidgets('① 空リストなら空状態ガイドを表示する', (tester) async {
    await tester.pumpWidget(_app(repo));
    repo.emit(const []);
    await tester.pump();

    expect(find.textContaining('最初のメッセージを送ってみましょう'), findsOneWidget);
  });

  testWidgets('② メッセージ2件を表示する（自分/相手）', (tester) async {
    await tester.pumpWidget(_app(repo));
    repo.emit(const [
      ChatMessage(id: 'm1', senderId: 'seller1', text: '受け渡し場所は？'),
      ChatMessage(id: 'm2', senderId: 'buyer1', text: '豊洲でお願いします'),
    ]);
    await tester.pump();

    expect(find.text('受け渡し場所は？'), findsOneWidget);
    expect(find.text('豊洲でお願いします'), findsOneWidget);
  });

  testWidgets('③ 送信で sendMessage が正しい引数で呼ばれ、入力欄がクリアされる',
      (tester) async {
    await tester.pumpWidget(_app(repo));
    repo.emit(const []);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'こんにちは');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(repo.sent, hasLength(1));
    expect(repo.sent.single.roomId, 'free_item1');
    expect(repo.sent.single.senderId, 'buyer1');
    expect(repo.sent.single.text, 'こんにちは');
    // 送信後、入力欄は空になる。
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
  });

  testWidgets('④ 空文字送信では sendMessage が呼ばれない', (tester) async {
    await tester.pumpWidget(_app(repo));
    repo.emit(const []);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(repo.sent, isEmpty);
  });
}
