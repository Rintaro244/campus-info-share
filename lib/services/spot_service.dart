import 'dart:io';
import 'package:characters/characters.dart';
import 'package:uuid/uuid.dart';
import '../models/spot.dart';
import '../models/spot_review.dart';
import '../repositories/post_repository.dart';
import '../repositories/storage_repository.dart';
import '../shared/exceptions.dart';

//C3の範囲
//Repository(データベース)に仕事を割り振るだけ
class SpotService {
  final PostRepository _postRepository;
  final StorageRepository _storageRepository;

  SpotService({
    PostRepository? postRepository,
    StorageRepository? storageRepository,
  })  : _postRepository = postRepository ?? PostRepository(),
        _storageRepository = storageRepository ?? StorageRepository();

  // M6-1: スポット検索
  Future<List<Spot>> searchSpots(
    Campus campus, {
    String sortBy = 'newly_created',
  }) async {
    final spots = await _postRepository.getSpotsByCampus(campus);
    if (sortBy == 'rating_desc') {
      // TODO: 評価順ソートは別途実装予定
    }
    return spots;
  }

  // M6-2: スポット投稿
  Future<String> postSpot({
    required String spotName,
    required Campus campus,
    required String category,
    required String authorUid,
    String? description,
    double? latitude,
    double? longitude,
    List<File> imageFiles = const [],
  //Firestore遅いので、asyncで非同期処理する
  }) async {
    // 入力チェック
    if (spotName.trim().isEmpty) {
      throw ValidationException('スポット名を入力してください');
    }
    if (spotName.characters.length > 50) {
      throw ValidationException('スポット名は50文字以内で入力してください');
    }
    if (category.isEmpty) {
      throw ValidationException('カテゴリを選択してください');
    }

    // 重複チェック（同キャンパス内の同名スポット）
    final existing = await _postRepository.getSpotsByCampus(campus);
    if (existing.any((s) => s.spotName == spotName)) {
      throw DuplicateSpotException();
    }

    //画像のアップロードとスポットの作成
    final spotId = const Uuid().v4();
    List<String> imageUrls = [];
    if (imageFiles.isNotEmpty) {
      imageUrls = await Future.wait(
        //storageRepository.uploadSpotImage(f, spotId)で画像をアップロードしてURLを取得,storageRepository.dartにつながる
        imageFiles.map((f) => _storageRepository.uploadSpotImage(f, spotId)),
      );
    }

    //Firestoreにスポットを作成する,PostRepository.dartにつながる
    await _postRepository.createSpot(
      spotId: spotId,
      spotName: spotName,
      campus: campus,
      category: category,
      authorUid: authorUid,
      description: description,
      latitude: latitude,
      longitude: longitude,
      imageUrls: imageUrls,
    );

    return 'success';  
  }

  // M6-3: スポット削除
  Future<void> deleteSpot(String spotId, String requestingUid) async {
    final spot = await _postRepository.getSpotById(spotId);
    if (spot.authorUid != requestingUid) throw PermissionDeniedException();
    await Future.wait([
      _postRepository.deleteSpot(spotId),
      _storageRepository.deleteSpotImages(spotId),
    ]);
  }

  // M6-4: レビュー投稿（バリデーション + PostRepository への委譲）
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
    return _postRepository.addReview(
      spotId: spotId,
      starRating: starRating,
      comment: comment,
      authorUid: authorUid,
    );
  }

  // パススルー（画面が PostRepository を直接触らないようにするための委譲）
  Future<Spot> getSpotById(String spotId) =>
      _postRepository.getSpotById(spotId);

  Future<List<SpotReview>> getReviews(String spotId) =>
      _postRepository.getReviews(spotId);
}
