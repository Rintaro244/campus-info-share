import 'dart:io';
import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/spot.dart';
import '../models/spot_review.dart';
import '../shared/exceptions.dart';
import 'storage_repository.dart';

class PostRepository {
  final FirebaseFirestore _firestore;
  final StorageRepository _storageRepository;

  static const String _spotsCollection = 'spots';
  static const String _reviewsCollection = 'reviews';

  PostRepository({
    FirebaseFirestore? firestore,
    StorageRepository? storageRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageRepository = storageRepository ?? StorageRepository();

  // ── スポット ─────────────────────────────────────────

  /// キャンパスでフィルタしてスポット一覧を取得する（新着順）。
  Future<List<Spot>> getSpotsByCampus(Campus campus) async {
    try {
      final snapshot = await _firestore
          .collection(_spotsCollection)
          .where('campus', isEqualTo: campus.label)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _docToSpot(doc)).toList();
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  /// spotId でスポット1件を取得する。
  Future<Spot> getSpotById(String spotId) async {
    try {
      final doc =
          await _firestore.collection(_spotsCollection).doc(spotId).get();
      if (!doc.exists) throw PostNotFoundException();
      return _docToSpot(doc);
    } on PostNotFoundException {
      rethrow;
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  /// スポットを新規投稿する。画像ファイルが渡された場合はアップロードも行う。
  Future<Spot> createSpot({
    required String spotName,
    required Campus campus,
    required String category,
    required String authorUid,
    String? description,
    double? latitude,
    double? longitude,
    List<File> imageFiles = const [],
  }) async {
    _validateSpotName(spotName);

    final spotId = const Uuid().v4();
    List<String> imageUrls = [];

    if (imageFiles.isNotEmpty) {
      imageUrls = await Future.wait(
        imageFiles.map((f) => _storageRepository.uploadSpotImage(f, spotId)),
      );
    }

    final data = {
      'spotName': spotName,
      'campus': campus.label,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'authorUid': authorUid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection(_spotsCollection).doc(spotId).set(data);
      return Spot(
        spotId: spotId,
        spotName: spotName,
        campus: campus,
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        authorUid: authorUid,
      );
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  /// スポットを削除する。投稿者本人のみ許可。
  Future<void> deleteSpot(String spotId, String requestingUid) async {
    final spot = await getSpotById(spotId);
    if (spot.authorUid != requestingUid) throw PermissionDeniedException();

    try {
      await Future.wait([
        _firestore.collection(_spotsCollection).doc(spotId).delete(),
        _storageRepository.deleteSpotImages(spotId),
      ]);
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  // ── レビュー ─────────────────────────────────────────

  /// スポットのレビュー一覧を取得する（新着順）。
  Future<List<SpotReview>> getReviews(String spotId) async {
    try {
      final snapshot = await _firestore
          .collection(_spotsCollection)
          .doc(spotId)
          .collection(_reviewsCollection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _docToReview(doc, spotId)).toList();
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  /// レビューを投稿する。
  Future<SpotReview> addReview({
    required String spotId,
    required int starRating,
    required String comment,
    required String authorUid,
  }) async {
    if (starRating < 1 || starRating > 5) {
      throw ValidationException('星評価は1〜5で指定してください');
    }
    if (comment.isEmpty) {
      throw ValidationException('コメントを入力してください');
    }
    if (comment.characters.length > 512) {
      throw ValidationException('コメントは512文字以内で入力してください');
    }

    final reviewId = const Uuid().v4();
    final spotRef = _firestore.collection(_spotsCollection).doc(spotId);
    final reviewRef =
        spotRef.collection(_reviewsCollection).doc(reviewId);

    try {
      // トランザクションでレビュー追加と平均評価・件数の更新を同時に行う
      await _firestore.runTransaction((transaction) async {
        final spotDoc = await transaction.get(spotRef);
        if (!spotDoc.exists) throw PostNotFoundException();

        final d = spotDoc.data()!;
        final currentCount = (d['reviewCount'] as int?) ?? 0;
        final currentAvg = (d['averageRating'] as num?)?.toDouble() ?? 0.0;
        final newCount = currentCount + 1;
        final newAvg = ((currentAvg * currentCount) + starRating) / newCount;

        transaction.set(reviewRef, {
          'spotId': spotId,
          'starRating': starRating,
          'comment': comment,
          'authorUid': authorUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(spotRef, {
          'averageRating': newAvg,
          'reviewCount': newCount,
        });
      });
    } on PostNotFoundException {
      rethrow;
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }

    return SpotReview(
      reviewId: reviewId,
      spotId: spotId,
      starRating: starRating,
      comment: comment,
      authorUid: authorUid,
      createdAt: DateTime.now(),
    );
  }

  /// レビューを削除する。投稿者本人のみ許可。
  Future<void> deleteReview({
    required String spotId,
    required String reviewId,
    required String requestingUid,
  }) async {
    try {
      final doc = await _firestore
          .collection(_spotsCollection)
          .doc(spotId)
          .collection(_reviewsCollection)
          .doc(reviewId)
          .get();
      if (!doc.exists) throw PostNotFoundException('レビューが見つかりません');
      if (doc.data()?['authorUid'] != requestingUid) {
        throw PermissionDeniedException();
      }
      await doc.reference.delete();
    } on PostNotFoundException {
      rethrow;
    } on PermissionDeniedException {
      rethrow;
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  // ── 内部変換 ──────────────────────────────────────────

  Spot _docToSpot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Spot.fromMap({
      ...data,
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    }, doc.id);
  }

  SpotReview _docToReview(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String spotId,
  ) {
    final data = doc.data()!;
    return SpotReview.fromMap({
      ...data,
      'spotId': spotId,
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    }, doc.id);
  }

  void _validateSpotName(String name) {
    if (name.isEmpty) throw ValidationException('スポット名を入力してください');
    if (name.length > 50) throw ValidationException('スポット名は50文字以内で入力してください');
  }
}
