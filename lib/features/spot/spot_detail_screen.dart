import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/spot.dart';
import '../../models/spot_review.dart';
import '../../services/spot_service.dart';
import '../../shared/exceptions.dart';

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _service = SpotService();
  final _commentController = TextEditingController();
  late Spot _spot;
  List<SpotReview> _reviews = [];
  bool _isLoadingReviews = false;
  String? _reviewError;
  String? _spotError;
  int _selectedStars = 5;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _spot = widget.spot;
    _loadSpot();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // W18 E1: スポット詳細データ取得失敗
  Future<void> _loadSpot() async {
    setState(() => _spotError = null);
    try {
      final spot = await _service.getSpotById(_spot.spotId);
      setState(() => _spot = spot);
    } on PostNotFoundException {
      setState(() => _spotError = 'スポット情報を取得できませんでした。通信環境を確認してください');
    } on NetworkException {
      setState(() => _spotError = 'スポット情報を取得できませんでした。通信環境を確認してください');
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewError = null;
    });
    try {
      final reviews = await _service.getReviews(_spot.spotId);
      setState(() => _reviews = reviews);
    } on NetworkException catch (e) {
      setState(() => _reviewError = e.message);
    } finally {
      setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final review = await _service.addReview(
        spotId: _spot.spotId,
        starRating: _selectedStars,
        comment: comment,
        authorUid: uid,
      );
      _commentController.clear();
      setState(() => _reviews.insert(0, review));
    } on ValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openInMaps() async {
    final lat = _spot.latitude;
    final lng = _spot.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // W18 E1: スポット詳細データ取得失敗
    if (_spotError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('スポット詳細')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_spotError!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('一覧へ戻る'),
              ),
            ],
          ),
        ),
      );
    }

    // レイアウトは常に1カラム（コメントは一番下）。ワイド幅では横幅いっぱいを使い、
    // 地図・入力欄・見出しのサイズも大きめに調整して比率が崩れないようにする。
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_spot.spotName),
        
      ),
      // 詳細は"読む"画面なので中央寄せの1カラム（約900px）。全幅にせず散らばりを防ぐ。
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SizedBox.expand(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      _buildImageCarousel(),
                      _buildInfoCard(),
                      _buildAccessSection(isWide),
                      const Divider(height: 1),
                      _buildCommentsSection(isWide),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                _buildCommentInputBar(isWide),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    final urls = _spot.imageUrls;
    // 中央寄せ(約900px)の列幅いっぱいに16:9で表示。containで見切れ防止。
    if (urls.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.grey[200],
          child: const Center(
              child: Icon(Icons.place, size: 64, color: Colors.grey)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.grey[100],
        child: PageView.builder(
          itemCount: urls.length,
          itemBuilder: (context, index) => Image.network(
            urls[index],
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey[200],
              child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final spot = _spot;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトルと平均星評価を同じ行にまとめて見出しにする（分散を防ぐ）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    spot.spotName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 20, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        spot.averageRating != null
                            ? spot.averageRating!.toStringAsFixed(1)
                            : '-',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        spot.reviewCount != null
                            ? '(${spot.reviewCount}件)'
                            : '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (spot.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: spot.tags
                    .map((tag) => _TagChip(label: tag))
                    .toList(),
              ),
            ],
            if (spot.hours != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(spot.hours!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessSection(bool isWide) {
    final lat = _spot.latitude;
    final lng = _spot.longitude;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_pin, size: isWide ? 20 : 16, color: Colors.red),
              const SizedBox(width: 6),
              Text('アクセス',
                  style: TextStyle(
                      fontSize: isWide ? 18 : 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (lat != null && lng != null)
                TextButton(
                  onPressed: _openInMaps,
                  child: const Text('マップで開く'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: isWide ? 300 : 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: lat != null && lng != null
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng), zoom: 15),
                      markers: {
                        Marker(
                          markerId: const MarkerId('spot'),
                          position: LatLng(lat, lng),
                          infoWindow:
                              InfoWindow(title: _spot.spotName),
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: Text('地図を読み込めませんでした',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(bool isWide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('コメント',
                style: TextStyle(
                    fontSize: isWide ? 20 : 16, fontWeight: FontWeight.bold)),
          ),
          if (_isLoadingReviews)
            const Center(child: CircularProgressIndicator())
          else if (_reviewError != null)
            Column(
              children: [
                Text(_reviewError!),
                TextButton(
                    onPressed: _loadReviews,
                    child: const Text('再読み込み')),
              ],
            )
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('まだコメントはありません',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ReviewTile(review: _reviews[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar(bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isWide ? 12 : 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 星評価（タップで変更）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStars = star),
                  child: Icon(
                    star <= _selectedStars ? Icons.star : Icons.star_border,
                    size: isWide ? 28 : 22,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: isWide ? 48 : 38,
                child: TextField(
                  controller: _commentController,
                  style: TextStyle(fontSize: isWide ? 15 : 14),
                  decoration: const InputDecoration(
                    hintText: 'コメントを入力… *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLength: 512,
                  maxLines: 1,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 送信ボタン
            SizedBox(
              width: isWide ? 44 : 34,
              height: isWide ? 44 : 34,
              child: FloatingActionButton(
                heroTag: 'send',
                mini: true,
                onPressed: _commentController.text.trim().isEmpty ||
                        _isSubmitting
                    ? null
                    : _submitComment,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.arrow_forward, size: isWide ? 20 : 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final SpotReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            child: Text(
              review.authorUid.substring(0, 2).toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < review.starRating
                            ? Icons.star
                            : Icons.star_border,
                        size: 14,
                        color: Colors.amber,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _relativeTime(review.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(review.comment,
                    maxLines: null,
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 30) return '${diff.inDays}日前';
    return '${dt.month}/${dt.day}';
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
    );
  }
}
