import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../shared/exceptions.dart';

class StorageRepository {
  final FirebaseStorage _storage;
  static const int _maxBytes = 1024 * 1024; // 1MB

  StorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// スポット画像をアップロードし、ダウンロードURLを返す。
  /// ファイルが1MBを超える場合は自動圧縮する。
  Future<String> uploadSpotImage(File imageFile, String spotId) async {
    try {
      final compressed = await _compressIfNeeded(imageFile);
      final fileName = '${const Uuid().v4()}.jpg';
      final ref = _storage.ref('spots/$spotId/$fileName');
      await ref.putFile(compressed);
      return await ref.getDownloadURL();
    } on ImageCompressionException {
      rethrow;
    } on UnsupportedFormatException {
      rethrow;
    } on FirebaseException catch (e) {
      throw StorageException(e.message ?? 'アップロードに失敗しました');
    }
  }

  /// スポットに紐づく画像を全て削除する。
  Future<void> deleteSpotImages(String spotId) async {
    try {
      final ref = _storage.ref('spots/$spotId');
      final result = await ref.listAll();
      await Future.wait(result.items.map((item) => item.delete()));
    } on FirebaseException catch (e) {
      throw StorageException(e.message ?? '画像の削除に失敗しました');
    }
  }

  Future<File> _compressIfNeeded(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length <= _maxBytes) return file;

    final ext = file.path.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
      throw UnsupportedFormatException('対応フォーマット: jpg/png/webp');
    }

    // 品質を段階的に下げて1MB以下を目指す
    for (final quality in [80, 60, 40, 20]) {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (result.length <= _maxBytes) {
        final tmpPath = '${file.parent.path}/compressed_${file.uri.pathSegments.last}';
        return File(tmpPath)..writeAsBytesSync(result);
      }
    }

    throw ImageCompressionException('画像を1MB以下に圧縮できませんでした');
  }
}
