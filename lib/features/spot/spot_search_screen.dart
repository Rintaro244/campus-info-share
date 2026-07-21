import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../shared/exceptions.dart';
import 'spot_detail_screen.dart';
import 'spot_post_screen.dart';

// W16: おすすめスポット検索（Web共通レイアウト）
// 班員の検索画面（サークル・教材取引）と様式を統一：
// AppBar + キーワード検索 + キャンパス/カテゴリのフィルタ + カード一覧 + 投稿FAB
class SpotSearchScreen extends StatefulWidget {
  const SpotSearchScreen({super.key});

  @override
  State<SpotSearchScreen> createState() => _SpotSearchScreenState();
}

class _SpotSearchScreenState extends State<SpotSearchScreen> {
  final _service = SpotService();

  // フィルタは班員UIに合わせて日本語ラベルの文字列で保持する
  static const _campusOptions = ['すべて', '豊洲', '大宮'];
  static const _categoryOptions = [
    'すべて', 'カフェ', '飲食店', '勉強スペース', '公園', 'ショッピング', 'その他'
  ];

  String _keyword = '';
  String _selectedCampus = 'すべて';
  String _selectedCategory = 'すべて';

  // ネットワークから取得した全スポット（フィルタ前）。絞り込みはメモリ内で行う。
  List<Spot> _allSpots = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAllSpots();
  }

  // フィルタのキャンパスラベルを Campus?（すべて→null）に変換する
  Campus? get _campusFilter =>
      _selectedCampus == 'すべて' ? null : Campus.fromString(_selectedCampus);

  // 現在のフィルタ条件をメモリ内で適用した表示用リスト（ネットワーク不要）。
  List<Spot> get _visibleSpots => _service.filterSpots(
        _allSpots,
        campus: _campusFilter,
        keyword: _keyword,
        category: _selectedCategory,
      );

  // Firestore からの取得は「初回」「投稿完了後」「エラー再読み込み」だけに限定する。
  // キーワード/フィルタ変更は _visibleSpots のメモリ内絞り込みで即時応答する（§4.1 性能）。
  Future<void> _fetchAllSpots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final spots = await _service.searchSpots();
      setState(() => _allSpots = spots);
    } on NetworkException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('おすすめスポット検索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'キーワード検索',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                // メモリ内フィルタなので再取得せず setState のみ（§4.1 即時応答）
                setState(() => _keyword = val);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FilterDropdown(
                icon: Icons.school,
                value: _selectedCampus,
                options: _campusOptions,
                onChanged: (v) => setState(() => _selectedCampus = v),
              ),
              _FilterDropdown(
                icon: Icons.category,
                value: _selectedCategory,
                options: _categoryOptions,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 投稿画面に入る前にログイン判定（未ログインなら遷移させない）
          if (FirebaseAuth.instance.currentUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('投稿するにはログインが必要です')),
            );
            return;
          }
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => SpotPostScreen(
                initialCampus: _campusFilter ?? Campus.toyosu,
              ),
            ),
          );
          if (created == true) _fetchAllSpots();
        },
        backgroundColor: Colors.blue[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('スポットを投稿',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAllSpots,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }
    final spots = _visibleSpots;
    if (spots.isEmpty) {
      // データなし画面は空白にせず投稿を促す（要求仕様書 §4.2）
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('該当するスポットが見つかりませんでした'),
            const SizedBox(height: 4),
            const Text('右下のボタンから投稿してみましょう',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    // レスポンシブ対応（要求仕様書7章）：スマホ1列→タブレット2列→PC3列
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200 ? 3 : (width >= 600 ? 2 : 1);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 224,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: spots.length,
          itemBuilder: (context, index) => _SpotCard(spot: spots[index]),
        );
      },
    );
  }
}

// キャンパス/カテゴリ用のアイコン付きドロップダウン
class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 4),
        DropdownButton<String>(
          value: value,
          items: options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _SpotCard extends StatelessWidget {
  final Spot spot;
  const _SpotCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 212,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryChip(label: spot.category),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          spot.spotName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StarRating(
                        rating: spot.averageRating,
                        count: spot.reviewCount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (spot.walkMinutes != null) ...[
                        const Icon(Icons.directions_walk,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          '徒歩${spot.walkMinutes}分',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (spot.priceRange != null)
                        Text(
                          spot.priceRange!,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey),
                        ),
                      const Spacer(),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SpotDetailScreen(spot: spot),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('詳細'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (spot.imageUrls.isEmpty) {
      return Container(
        height: 110,
        color: Colors.grey[200],
        child: const Center(
            child: Icon(Icons.place, size: 40, color: Colors.grey)),
      );
    }
    return Image.network(
      spot.imageUrls.first,
      height: 110,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 110,
        color: Colors.grey[200],
        child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double? rating;
  final int? count;
  const _StarRating({this.rating, this.count});

  @override
  Widget build(BuildContext context) {
    final label = rating != null ? rating!.toStringAsFixed(1) : '-';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 14, color: Colors.amber),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
