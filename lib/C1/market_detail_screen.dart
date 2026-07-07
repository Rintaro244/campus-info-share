// lib/C1/market_detail_screen.dart

import 'package:flutter/material.dart';
import '../C3/market_model.dart';

class MarketDetailScreen extends StatelessWidget {
  final MarketModel product;

  const MarketDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品詳細')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Container(
                    width: double.infinity,
                    height: 300, // 💡 高さを300に固定
                    color: Colors.black87, // 💡 余白を黒にして画像を引き締める
                    // 💡 fitを contain にして見切れを防止
                    child: Image.network(
                      product.imageUrl!,
                      fit: BoxFit.contain,
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¥${product.price}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    product.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Chip(
                        label: Text(product.campus),
                        backgroundColor: Colors.blue[50],
                        labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(product.condition),
                        backgroundColor: Colors.green[50],
                        labelStyle: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    '商品の説明',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),

                  const SizedBox(height: 40),
                  // TODO(木幡さん): C4 取引・決済ロジックが完了したら、このボタンから決済処理(executePurchase等)の呼び出し連携をお願いします。
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('購入手続き（決済ロジック連携待ち）')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      '購入手続きへ進む',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}