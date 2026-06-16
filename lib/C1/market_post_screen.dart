// lib/C1/market_post_screen.dart

import 'package:flutter/material.dart';
import 'market_validator.dart';

class MarketPostScreen extends StatefulWidget {
  const MarketPostScreen({Key? key}) : super(key: key);

  @override
  State<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends State<MarketPostScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text;
    final priceStr = _priceController.text;
    final desc = _descController.text;

    // 💡 独立させたValidatorを使ってチェック
    if (!MarketValidator.validateItem(title: title, priceStr: priceStr, description: desc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('入力内容に不備があります。文字数や価格を確認してください。'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('教材を出品しました！')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教材を出品する')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '商品名（40文字以内）')),
            TextField(controller: _priceController, decoration: const InputDecoration(labelText: '価格（0〜100,000円）'), keyboardType: TextInputType.number),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: '商品説明（1000文字以内）'), maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('出品を登録する'),
            ),
          ],
        ),
      ),
    );
  }
}