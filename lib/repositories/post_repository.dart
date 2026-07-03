import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/spot.dart';
import '../models/spot_review.dart';
import '../shared/exceptions.dart';

//Firestoreのデータベース(コレクション)を操作するためのクラス
class PostRepository {
  //firestoreのインスタンスを取得
  final FirebaseFirestore _firestore;

  //collectionを追加していってください
  static const String _spotsCollection = 'spots';
  static const String _reviewsCollection = 'reviews';

  PostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── スポット ─────────────────────────────────────────

  /// キャンパスでフィルタしてスポット一覧を取得する（新着順）。
  Future<List<Spot>> getSpotsByCampus(Campus campus) async {
    //whereで絞り込み、orderByで並び替え、getで取得する。取得したドキュメントをSpotに変換してリストで返す。
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

  /// spotIdを参考にスポット1件を取得する。スポット一覧は取らない。
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

  /// スポットを Firestore に保存する。
  Future<Spot> createSpot({
    required String spotId,
    required String spotName,
    required Campus campus,
    required String category,
    required String authorUid,
    String? description,
    double? latitude,
    double? longitude,
    List<String> imageUrls = const [],
  }) async {
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
      //spotsコレクション→ドキュメントIDをspotIdにしてデータを書き込む
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

  /// Firestore のスポットドキュメントを削除する。
  /// 消すかの権限はService.dartで確認する。
  Future<void> deleteSpot(String spotId) async {
    try {
      await _firestore.collection(_spotsCollection).doc(spotId).delete();
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
          //spotIdのドキュメントの中にreviewsコレクションがあるので、そこを参照する(入れ子構造)
          //スポットごとのレビューをまとめられる
          .collection(_reviewsCollection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _docToReview(doc, spotId)).toList();
    } on FirebaseException catch (e) {
      throw NetworkException(e.message ?? '通信環境を確認してください');
    }
  }

  /// レビューを投稿する。平均評価・件数の更新も同時に行う。
  Future<SpotReview> addReview({
    required String spotId,
    required int starRating,
    required String comment,
    required String authorUid,
  }) async {
    final reviewId = const Uuid().v4();
    //ドキュメントの場所を指定するための参照を作る(spotRefとreviewRef)、一々_firestore.collection('spots').doc(spotId)書くのの大変
    final spotRef = _firestore.collection(_spotsCollection).doc(spotId);
    final reviewRef =
        spotRef.collection(_reviewsCollection).doc(reviewId);

    try {
      //トランザクション：「この中の処理は全部成功か、全部失敗か、どちらかしかないという保証
      // トランザクションでレビュー追加と平均評価・件数の更新を同時に行う
      await _firestore.runTransaction((transaction) async {
        //今のスポット情報を取得
        final spotDoc = await transaction.get(spotRef);
        if (!spotDoc.exists) throw PostNotFoundException();

        final d = spotDoc.data()!;
        final currentCount = (d['reviewCount'] as int?) ?? 0;
        final currentAvg = (d['averageRating'] as num?)?.toDouble() ?? 0.0;
        //heikin
        final newCount = currentCount + 1;
        final newAvg = ((currentAvg * currentCount) + starRating) / newCount;

        transaction.set(reviewRef, {
          //レビューの中身
          'spotId': spotId,
          'starRating': starRating,
          'comment': comment,
          'authorUid': authorUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(spotRef, {
          //平均評価と件数を更新
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
  /// Repositoryだが権限チェックしている、他人のレビューを消すことはできないようにするため
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

  // ── 内部変換 ──────────────────
  //Firestoreから返ってくるドキュメントをSpot型に変換する
  //生データを整えている
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
}
