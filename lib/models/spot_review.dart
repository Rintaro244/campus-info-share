class SpotReview {
  final String reviewId;
  final String spotId;
  final int starRating;
  final String comment;
  final String authorUid;
  final DateTime createdAt;

  const SpotReview({
    required this.reviewId,
    required this.spotId,
    required this.starRating,
    required this.comment,
    required this.authorUid,
    required this.createdAt,
  });

  factory SpotReview.fromMap(Map<String, dynamic> data, String id) {
    return SpotReview(
      reviewId: id,
      spotId: data['spotId'] as String,
      starRating: data['starRating'] as int,
      comment: data['comment'] as String,
      authorUid: data['authorUid'] as String,
      createdAt: data['createdAt'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotId': spotId,
      'starRating': starRating,
      'comment': comment,
      'authorUid': authorUid,
      'createdAt': createdAt,
    };
  }

  SpotReview copyWith({
    String? reviewId,
    String? spotId,
    int? starRating,
    String? comment,
    String? authorUid,
    DateTime? createdAt,
  }) {
    return SpotReview(
      reviewId: reviewId ?? this.reviewId,
      spotId: spotId ?? this.spotId,
      starRating: starRating ?? this.starRating,
      comment: comment ?? this.comment,
      authorUid: authorUid ?? this.authorUid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
