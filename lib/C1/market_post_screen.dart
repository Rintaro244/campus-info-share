// lib/C1/market_post_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:student_information_1/payment/providers.dart';
import '../C3/market_manager.dart';
import 'market_validator.dart';

class MarketPostScreen extends ConsumerStatefulWidget {
  const MarketPostScreen({super.key});

  @override
  ConsumerState<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends ConsumerState<MarketPostScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCampus = '豊洲';
  String _selectedCondition = '目立った傷や汚れなし';

  Uint8List? _imageBytes; // 💡 画像データ保持
  bool _isUploading = false;

  /// 文字数カウンタを組み立てる。MarketValidator は trim 後の長さで判定するため、
  /// 表示も trim 後の値に合わせる（見た目が上限内なのに弾かれる、を防ぐ）。
  /// controller を直接購読するので、画面全体を再 build せずに数字だけ更新される。
  InputCounterWidgetBuilder _counterBuilder(TextEditingController controller) {
    return (
      BuildContext context, {
      required int currentLength,
      required bool isFocused,
      required int? maxLength,
    }) {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final length = value.text.trim().length;
          final isOver = maxLength != null && length > maxLength;
          return Text(
            '$length / $maxLength',
            style: TextStyle(
              fontSize: 12,
              color: isOver ? Theme.of(context).colorScheme.error : null,
              fontWeight: isOver ? FontWeight.bold : null,
            ),
          );
        },
      );
    };
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() { _imageBytes = bytes; });
    }
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final priceStr = _priceController.text.trim();
    final desc = _descController.text.trim();

    // 入力値の妥当性チェック（タイトル1〜40字・価格0〜100,000円・説明1〜1000字）。
    // Rules 側でも同じ範囲を強制するため、ここは早期のユーザー通知が目的。
    if (!MarketValidator.validateItem(
      title: title,
      priceStr: priceStr,
      description: desc,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('入力内容を確認してください（価格は0〜100,000円）'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 出品者はログイン中の本人。未ログインでは出品不可（Rules も本人以外を弾く）。
    final sellerId = ref.read(currentUidProvider);
    if (sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出品するにはログインが必要です'), backgroundColor: Colors.red),
      );
      return;
    }

    final price = int.tryParse(priceStr) ?? 0;

    setState(() { _isUploading = true; });

    final success = await MarketManager().registerProduct(
      title: title,
      price: price,
      campus: _selectedCampus,
      condition: _selectedCondition,
      description: desc,
      imageBytes: _imageBytes, // 💡 画像をマネージャーに渡す
      sellerId: sellerId,
    );

    if (!mounted) return;
    setState(() { _isUploading = false; });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('出品しました！')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出品に失敗しました'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品を出品')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 💡 画像選択エリアを追加
            // 選択済みのときだけ右上に削除ボタンを重ねる（未選択に戻せるようにする）。
            // タップ＝選び直しなので、ピッカーのキャンセルでは消さない（誤操作防止）。
            Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                Image.memory(_imageBytes!, fit: BoxFit.contain),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 50, color: Colors.grey),
                              Text('商品の写真を追加',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                if (_imageBytes != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: '画像を削除',
                        onPressed: () => setState(() => _imageBytes = null),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '商品名（教科書名など）'),
              maxLength: MarketValidator.maxTitleLength,
              // 上限を超えた入力を「止めない」。止めると境界値（41文字）の
              // バリデーション動作を画面から確認できなくなるため。
              maxLengthEnforcement: MaxLengthEnforcement.none,
              buildCounter: _counterBuilder(_titleController),
            ),
            TextField(controller: _priceController, decoration: const InputDecoration(labelText: '価格（半角数字）'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              initialValue: _selectedCampus,
              decoration: const InputDecoration(labelText: '受け渡しキャンパス'),
              items: ['豊洲', '大宮', '両方'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCampus = val!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _selectedCondition,
              decoration: const InputDecoration(labelText: '商品の状態'),
              items: ['新品同様', '目立った傷や汚れなし', 'やや傷や汚れあり', '状態が悪い'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCondition = val!),
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '商品の詳細説明'),
              maxLines: 3,
              maxLength: MarketValidator.maxDescriptionLength,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              buildCounter: _counterBuilder(_descController),
            ),
            const SizedBox(height: 32),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('出品する', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }
}