/// 学内情報共有システム — C4 取引・決済処理部
/// 価格表示ウィジェット（一覧・詳細・支払選択で共有）
///
/// 0円は「無料」バッジ、価格未設定（null）は「価格未設定」、それ以外は「¥価格」。
library;

import 'package:flutter/material.dart';

/// 価格表示（0円は「無料」バッジ、未設定は「価格未設定」）。
class ItemPriceLabel extends StatelessWidget {
  final int? price;
  final double fontSize;

  const ItemPriceLabel({super.key, required this.price, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final price = this.price;
    if (price == null) {
      return Text(
        '価格未設定',
        style: TextStyle(fontSize: fontSize, color: Colors.grey),
      );
    }
    if (price == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '無料',
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Text(
      '¥$price',
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
    );
  }
}
