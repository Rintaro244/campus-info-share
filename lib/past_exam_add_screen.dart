import 'dart:io';
import 'package:flutter/foundation.dart'; // 💡 kIsWeb（Webかどうかの判定）を使うために追加
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'past_exam_controller.dart';

class PastExamAddScreen extends ConsumerStatefulWidget {
  const PastExamAddScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PastExamAddScreen> createState() => _PastExamAddScreenState();
}

class _PastExamAddScreenState extends ConsumerState<PastExamAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _subjectController = TextEditingController();
  final _professorController = TextEditingController();
  
  // 💡 修正ポイント1：File ではなく XFile のまま保存する
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _subjectController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  /// スマホのアルバムから画像を複数枚選択する関数
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        // 💡 修正ポイント2：Fileに変換せず、XFileのままリストに追加する
        _selectedImages.addAll(images);
      });
    }
  }

  /// 投稿ボタンが押された時の処理
  Future<void> _submit() async {
    // 入力値のバリデーションチェック（未入力がないか）
    if (!_formKey.currentState!.validate()) return;
    
    // 画像が1枚も選ばれていない場合は警告を出す
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('過去問の写真を1枚以上選択してください'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final controller = ref.read(pastExamControllerProvider);
    
    // ControllerのsubmitExamを呼び出してFirebaseに保存
    // 💡 _selectedImages が XFile になったので、エラーが出なくなります！
    final success = await controller.submitExam(
      title: _titleController.text.trim(),
      year: int.parse(_yearController.text.trim()),
      subjectName: _subjectController.text.trim(),
      professorName: _professorController.text.trim(),
      imageFiles: _selectedImages,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('過去問を投稿しました！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // 投稿が成功したら一覧画面に戻る
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿に失敗しました。もう一度お試しください。'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Controllerの状態（isSubmittingなど）を監視
    final controllerState = ref.watch(pastExamControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('過去問の投稿', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          // アップロード中は戻れないように無効化
          onPressed: controllerState.isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // キーボード以外をタップしたら閉じる
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル入力
                const Text('タイトル', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  enabled: !controllerState.isSubmitting,
                  decoration: _buildInputDecoration('例: 2025年度 期末試験'),
                  validator: (value) => value == null || value.isEmpty ? 'タイトルを入力してください' : null,
                ),
                const SizedBox(height: 20),

                // 年度入力
                const Text('実施年度 (西暦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _yearController,
                  enabled: !controllerState.isSubmitting,
                  keyboardType: TextInputType.number, // 数字キーボードを表示
                  decoration: _buildInputDecoration('例: 2025'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '年度を入力してください';
                    if (int.tryParse(value) == null) return '半角数字で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 科目名入力
                const Text('科目名', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subjectController,
                  enabled: !controllerState.isSubmitting,
                  decoration: _buildInputDecoration('例: 基礎数学Ⅰ'),
                  validator: (value) => value == null || value.isEmpty ? '科目名を入力してください' : null,
                ),
                const SizedBox(height: 20),

                // 教授名入力
                const Text('教授名', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _professorController,
                  enabled: !controllerState.isSubmitting,
                  decoration: _buildInputDecoration('例: 田中 太郎 教授'),
                  validator: (value) => value == null || value.isEmpty ? '教授名を入力してください' : null,
                ),
                const SizedBox(height: 24),

                // 画像選択セクション
                const Text('過去問の写真 (複数枚可)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                
                // 選択された画像のプレビュー横スクロールリスト
                if (_selectedImages.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  // 💡 修正ポイント3：Web環境とスマホ環境で画像の表示方法を自動で切り替える
                                  image: kIsWeb 
                                      ? NetworkImage(_selectedImages[index].path) as ImageProvider
                                      : FileImage(File(_selectedImages[index].path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // 画像の削除ボタン（アップロード中でない場合のみ表示）
                            if (!controllerState.isSubmitting)
                              Positioned(
                                top: 0,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 画像を選択するボタン
                OutlinedButton.icon(
                  onPressed: controllerState.isSubmitting ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('アルバムから写真を追加'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    side: BorderSide(color: Colors.blue[300]!),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                
                const SizedBox(height: 40),

                // 投稿実行ボタン
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: controllerState.isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: controllerState.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('この内容で過去問を投稿する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // テキストフィールド共通の装飾スタイル
  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[600]!, width: 2), borderRadius: BorderRadius.circular(8)),
      errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(8)),
      focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent, width: 2), borderRadius: BorderRadius.circular(8)),
    );
  }
}