/// 学内情報共有システム — C4 取引・決済処理部
/// チャット画面（取引成立した購入者⇄出品者のやり取り）
///
/// メッセージは ChatRepository.watchMessages を StreamBuilder で購読する
/// （PastExam のリアルタイム表示パターンを踏襲）。送信者は currentUid で
/// 左右に振り分ける。roomId = transactionId。
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:student_information_1/payment/models/chat_message.dart';
import 'package:student_information_1/payment/services/chat_repository.dart';

/// 取引成立チャット画面。
class ChatScreen extends StatefulWidget {
  /// ルーム ID（= transactionId）。
  final String roomId;

  /// 送信者 uid。null の場合は FirebaseAuth の現在ユーザーを使う。
  final String? currentUid;

  /// メッセージ購読・送信のリポジトリ（テストで差し替え可能）。
  final ChatRepository? repository;

  const ChatScreen({
    super.key,
    required this.roomId,
    this.currentUid,
    this.repository,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepository _repository;
  late final String? _uid;
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ChatRepository();
    _uid = widget.currentUid ?? FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _uid == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        roomId: widget.roomId,
        senderId: _uid,
        text: text,
      );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出品者とのやり取り')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _repository.watchMessages(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // 品質要件: 1秒以上かかり得る処理はインジケータ必須。
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  // データなし画面は空白にせずガイドを表示する（UI 方針）。
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'まだメッセージはありません。\n最初のメッセージを送ってみましょう。',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMine = m.senderId == _uid;
                    return _MessageBubble(text: m.text, isMine: isMine);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _InputBar(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// メッセージの吹き出し（自分＝右、相手＝左）。
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;

  const _MessageBubble({required this.text, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      ),
    );
  }
}

/// 入力欄 + 送信ボタン。
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: ChatRepository.maxTextLength,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'メッセージを入力',
                  border: OutlineInputBorder(),
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send),
              tooltip: '送信',
            ),
          ],
        ),
      ),
    );
  }
}
