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
      // 画像を圧縮する必要がある場合は圧縮する
      final compressed = await _compressIfNeeded(imageFile);
      final fileName = '${const Uuid().v4()}.jpg';
      final ref = _storage.ref('spots/$spotId/$fileName');

      await ref.putFile(compressed);
      // アップロード後にダウンロードURLを取得して返す
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
      // フォルダ内の画像の一覧を取得して全て削除する
      final result = await ref.listAll();
      await Future.wait(result.items.map((item) => item.delete()));
    } on FirebaseException catch (e) {
      throw StorageException(e.message ?? '画像の削除に失敗しました');
    }
  }

  /// 画像を1MB以下に圧縮する。対応フォーマットはjpg/png/webp。
  /// 圧縮後も1MBを超える場合は例外を投げる。
  Future<File> _compressIfNeeded(File file) async {
    final bytes = await file.readAsBytes();
    // 1MB以下ならそのまま返す
    if (bytes.length <= _maxBytes) return file;

    final ext = file.path.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
      throw UnsupportedFormatException('対応フォーマット: jpg/png/webp');
    }

    // 品質を段階的に下げて1MB以下を目指す
    //画像の圧縮は品質を下げることで行う。FlutterImageCompressを使用して、品質を80, 60, 40, 20と段階的に下げて圧縮する。圧縮後の画像が1MB以下になったらその画像を返す。
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
