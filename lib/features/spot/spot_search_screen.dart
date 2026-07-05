import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../shared/exceptions.dart';
import 'spot_detail_screen.dart';
import 'spot_post_screen.dart';

// W16-a: キャンパス選択画面
class SpotSearchScreen extends StatelessWidget {
  const SpotSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          //Centerで縦方向に中央寄せする。Columnで縦方向に並べる。SizedBoxで余白を作る。OutlinedButtonでキャンパス選択ボタンを作る。_CampusCardでキャンパスカードを作る。
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_pin, size: 36, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              const Text(
                'SIT Spot',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '芝浦工業大学 スポット検索',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(164, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('キャンパスを選択', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 20),
              const Text(
                'どちらのキャンパスで\n探しますか？',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),
              _CampusCard(
                campus: Campus.toyosu,
                label: '豊洲キャンパス',
                sublabel: 'Toyosu Campus',
                iconColor: Colors.blue.shade100,
              ),
              const SizedBox(height: 12),
              _CampusCard(
                campus: Campus.omiya,
                label: '大宮キャンパス',
                sublabel: 'Omiya Campus',
                iconColor: Colors.teal.shade100,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampusCard extends StatelessWidget {
  final Campus campus;
  final String label;
  final String sublabel;
  final Color iconColor;

  const _CampusCard({
    required this.campus,
    required this.label,
    required this.sublabel,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 76,
      child: Card(
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          //Naiver.pushでSpotSearchListScreenに遷移する。Campusを引数として渡す。
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              //選んだキャンパスを引数としてSpotSearchListScreenに渡す
              builder: (_) => SpotSearchListScreen(campus: campus),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.apartment, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// W16-b: スポット一覧
//StatefulWidgetでSpotSearchListScreenを作る。StateでSpotServiceを使ってスポット一覧を取得する。FutureBuilderでスポット一覧を表示する。
//Statefulなので、クラスが2つに分かれる。SpotSearchListScreenと_SpotSearchListScreenState。
class SpotSearchListScreen extends StatefulWidget {
  final Campus campus;
  const SpotSearchListScreen({super.key, required this.campus});

  @override
  State<SpotSearchListScreen> createState() => _SpotSearchListScreenState();
}

class _SpotSearchListScreenState extends State<SpotSearchListScreen> {
  final _service = SpotService();//SpotServiceを使ってスポット一覧を取得する。
  late Campus _selectedCampus;
  List<Spot> _spots = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  //画面が初期化されたときに、_selectedCampusにwidget.campusを代入して、_loadSpots()を呼び出す。
  void initState() {
    super.initState();
    _selectedCampus = widget.campus;
    _loadSpots();
  }

  //データ取得の心臓部。SpotServiceのsearchSpots()を呼び出して、スポット一覧を取得する。取得中はローディング表示、エラー時はエラーメッセージを表示する。
  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final spots = await _service.searchSpots(_selectedCampus);
      setState(() => _spots = spots);//setStateでスポット一覧を更新する。
    } on NetworkException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<Campus>(
          value: _selectedCampus,
          underline: const SizedBox(),
          style: Theme.of(context).textTheme.titleMedium,
          items: Campus.values
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.label}キャンパス ▾'),
                  ))
              .toList(),
          onChanged: (c) {
            if (c == null) return;
            setState(() => _selectedCampus = c);
            _loadSpots();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            iconSize: 24,
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: SizedBox(
        width: 44,
        height: 44,
        child: FloatingActionButton(
          onPressed: () async {
            // TODO: 動作確認のため一時的にログインチェックをコメントアウト（テスト後に戻すこと）
            // final user = FirebaseAuth.instance.currentUser;
            // if (user == null) {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     const SnackBar(content: Text('ログインが必要です')),
            //   );
            //   return;
            // }
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SpotPostScreen(initialCampus: _selectedCampus),
              ),
            );
            if (created == true) _loadSpots();
          },
          child: const Icon(Icons.add),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department), label: '人気'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '履歴'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: 'お気に入り'),
        ],
      ),
    );
  }

  //画面の描画、スポット一覧の表示を行う。_isLoadingがtrueならローディング表示、_errorMessageがnullでないならエラーメッセージ表示、_spotsが空なら「スポットがまだありません」と表示する。それ以外はGridViewでスポット一覧を表示する。
  //状態に応じて出し分け
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
              onPressed: _loadSpots,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }
    if (_spots.isEmpty) {
      return const Center(child: Text('スポットがまだありません'));
    }
    // レスポンシブ対応（要求仕様書7章）：スマホ1列→タブレット2列→PC3列
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200 ? 3 : (width >= 600 ? 2 : 1);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 216,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _spots.length,
          itemBuilder: (context, index) => _SpotCard(spot: _spots[index]),
        );
      },
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
        height: 200,
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
                              builder: (_) =>
                                  SpotDetailScreen(spot: spot),
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
