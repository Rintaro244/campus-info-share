// データアクセス（スポット）
class PostNotFoundException implements Exception {
  final String message;
  PostNotFoundException([this.message = 'スポットが見つかりません']);

  @override
  String toString() => 'PostNotFoundException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException([this.message = '入力値が不正です']);

  @override
  String toString() => 'ValidationException: $message';
}

class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException([this.message = '操作する権限がありません']);

  @override
  String toString() => 'PermissionDeniedException: $message';
}

class DuplicateSpotException implements Exception {
  final String message;
  DuplicateSpotException([this.message = '同じキャンパスに同名のスポットが既に存在します']);

  @override
  String toString() => 'DuplicateSpotException: $message';
}

// ストレージ
class StorageException implements Exception {
  final String message;
  StorageException([this.message = 'ストレージ操作に失敗しました']);

  @override
  String toString() => 'StorageException: $message';
}

class ImageCompressionException implements Exception {
  final String message;
  ImageCompressionException([this.message = '画像を1MB以下に圧縮できませんでした']);

  @override
  String toString() => 'ImageCompressionException: $message';
}

class UnsupportedFormatException implements Exception {
  final String message;
  UnsupportedFormatException([this.message = '対応していないファイル形式です']);

  @override
  String toString() => 'UnsupportedFormatException: $message';
}

// ネットワーク・地図
class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = '通信環境を確認してください']);

  @override
  String toString() => 'NetworkException: $message';
}

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException([this.message = 'APIの利用上限に達しました']);

  @override
  String toString() => 'QuotaExceededException: $message';
}

class AddressNotFoundException implements Exception {
  final String message;
  AddressNotFoundException([this.message = '住所が見つかりません']);

  @override
  String toString() => 'AddressNotFoundException: $message';
}
