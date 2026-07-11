// lib/C1/circle_post_screen.dart

import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../C3/circle_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CirclePostScreen extends StatefulWidget {
  const CirclePostScreen({Key? key}) : super(key: key);

  @override
  State<CirclePostScreen> createState() => _CirclePostScreenState();
}

class _CirclePostScreenState extends State<CirclePostScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCampus = '豊洲';
  String _selectedCategory = '運動系';
  
  Uint8List? _imageBytes; 
  bool _isUploading = false; 

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submitPost() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('必須項目が入力されていません'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isUploading = true; }); 

    final success = await CircleManager().registerCircle(
      name: name,
      campus: _selectedCampus,
      category: _selectedCategory,
      description: desc,
      imageBytes: _imageBytes, 
      userId: FirebaseAuth.instance.currentUser?.uid ?? '', 
    );

    setState(() { _isUploading = false; }); 

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サークルを登録しました！')),
      );
      Navigator.pop(context, true); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録に失敗しました'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('サークルを登録')),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                        // 💡 fitを contain に変更して見切れを防止
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          Text('タップしてカバー画像を追加', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'サークル名')),
            DropdownButtonFormField<String>(
              value: _selectedCampus,
              decoration: const InputDecoration(labelText: 'キャンパス'),
              items: ['豊洲', '大宮', '両方'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCampus = val!),
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
              items: ['運動系', '文化系', 'その他'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: '紹介文'), maxLines: 3),
            const SizedBox(height: 32),
            
            _isUploading 
                ? const CircularProgressIndicator() 
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('登録する', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }
}