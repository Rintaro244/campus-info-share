import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/spot.dart';
import '../../repositories/map_api_client.dart';
import '../../services/spot_service.dart';
import '../../secrets.dart';
import '../../shared/exceptions.dart';

// 場所検索の候補をボトムシートで表示し、選ばれた1件を返す（複数ヒット時に使用）。
// 投稿画面・地図ピッカーの両方から使う共通ヘルパー。
Future<PlaceCandidate?> showPlaceCandidateSheet(
  BuildContext context,
  List<PlaceCandidate> candidates,
) {
  return showModalBottomSheet<PlaceCandidate>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('候補から選んでください',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = candidates[i];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.red),
                    title: Text(c.name),
                    subtitle: c.address.isEmpty ? null : Text(c.address),
                    onTap: () => Navigator.pop(sheetContext, c),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class SpotPostScreen extends StatefulWidget {
  final Campus initialCampus;
  const SpotPostScreen({super.key, this.initialCampus = Campus.toyosu});

  @override
  State<SpotPostScreen> createState() => _SpotPostScreenState();
}

class _SpotPostScreenState extends State<SpotPostScreen> {
  final _service = SpotService();
  final _mapClient = MapApiClient(apiKey: googleMapsApiKey);
  final _spotNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late Campus _selectedCampus;
  String? _selectedCategory;
  int _starRating = 5; // UC16: 投稿時の星評価（初期レビューとして登録）
  List<XFile> _selectedImages = [];
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  bool _isSubmitting = false;

  static const _categories = [
    'カフェ', '飲食店', '勉強スペース', '公園', 'ショッピング', 'その他'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCampus = widget.initialCampus;
  }

  @override
  void dispose() {
    _spotNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _mapClient.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages = images);
  }

  Future<void> _searchLocation() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
    try {
      // 店名の部分入力でも当たるよう Places 検索を使い、候補から選ばせる
      final candidates = await _mapClient.searchPlaces(
        query,
        biasLat: _selectedCampus.defaultLatitude,
        biasLng: _selectedCampus.defaultLongitude,
      );
      if (!mounted) return;
      final chosen = candidates.length == 1
          ? candidates.first
          : await showPlaceCandidateSheet(context, candidates);
      if (chosen == null) return;
      final location = LatLng(chosen.latitude, chosen.longitude);
      setState(() => _selectedLocation = location);
      await _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    } on AddressNotFoundException catch (e) {
      _showSnackBar(e.message);
    } on NetworkException catch (e) {
      _showSnackBar(e.message);
    }
  }

  // フォーム内の小さい地図ではクリックしづらいため、全画面のピッカーで位置を調整する
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MapPickerScreen(
          mapClient: _mapClient,
          initialTarget: _selectedLocation ??
              LatLng(_selectedCampus.defaultLatitude,
                  _selectedCampus.defaultLongitude),
          initialPin: _selectedLocation,
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedLocation = result);
      await _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(result, 16));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showSnackBar('写真を1枚以上選択してください');
      return;
    }
    if (_selectedLocation == null) {
      _showSnackBar('地図をクリックしてスポットの位置を指定してください');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('ログインが必要です');
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _service.postSpot(
        spotName: _spotNameController.text.trim(),
        campus: _selectedCampus,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        authorUid: uid,
        starRating: _starRating,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
        imageFiles: _selectedImages,
      );
      if (mounted) Navigator.pop(context, true);
    } on DuplicateSpotException catch (e) {
      _showSnackBar(e.message);
    } on ImageCompressionException catch (e) {
      _showSnackBar(e.message);
    } on ValidationException catch (e) {
      _showSnackBar(e.message);
    } on NetworkException catch (e) {
      _showSnackBar(e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // レスポンシブ対応（要求仕様書7章）：タブレット/PCでは入力フォームの幅を中央寄せで制限
    final width = MediaQuery.sizeOf(context).width;
    final maxContentWidth = width >= 600 ? 600.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('おすすめスポット投稿')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhotoArea(),
                  const SizedBox(height: 16),
                  _buildSpotNameField(),
                  const SizedBox(height: 16),
                  _buildCampusToggle(),
                  const SizedBox(height: 16),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildDescriptionField(),
                  const SizedBox(height: 16),
                  _buildStarRatingField(),
                  const SizedBox(height: 16),
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoArea() {
    if (_selectedImages.isEmpty) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 28, color: Colors.grey),
              SizedBox(height: 4),
              Text('写真を追加', style: TextStyle(color: Colors.grey)),
              Text('タップして選択',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.grey),
              ),
            );
          }
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder<Uint8List>(
                    future: _selectedImages[index].readAsBytes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(color: Colors.grey[200]);
                      }
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedImages.removeAt(index)),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black54,
                    child:
                        Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpotNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.location_pin, size: 16, color: Colors.red),
            SizedBox(width: 4),
            Text('スポット名',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _spotNameController,
          decoration: const InputDecoration(
            hintText: '例) 図書館前の芝生広場',
            border: OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
          maxLength: 50,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'スポット名を入力してください' : null,
        ),
      ],
    );
  }

  Widget _buildCampusToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.school, size: 16, color: Colors.blue),
            SizedBox(width: 4),
            Text('キャンパス',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        ToggleButtons(
          isSelected:
              Campus.values.map((c) => c == _selectedCampus).toList(),
          onPressed: (i) {
            final campus = Campus.values[i];
            setState(() => _selectedCampus = campus);
            // まだピンを置いていない場合は、選んだキャンパス周辺に地図を移動する
            if (_selectedLocation == null) {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(campus.defaultLatitude, campus.defaultLongitude),
                  16));
            }
          },
          borderRadius: BorderRadius.circular(6),
          children: Campus.values
              .map((c) => SizedBox(
                    width: 100,
                    child: Center(child: Text(c.label)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.category, size: 16, color: Colors.orange),
            SizedBox(width: 4),
            Text('カテゴリ',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: const InputDecoration(
            hintText: 'カテゴリを選択 ▾',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
          validator: (v) => v == null ? 'カテゴリを選択してください' : null,
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.edit, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text('おすすめポイント',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            hintText: 'このスポットの魅力を教えてください。',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          maxLines: 4,
          maxLength: 500,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'おすすめポイントを入力してください'
              : null,
        ),
      ],
    );
  }

  // UC16: 写真＋おすすめポイントに対する星評価。投稿時に初期レビューとして登録される。
  Widget _buildStarRatingField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star, size: 16, color: Colors.amber),
            SizedBox(width: 4),
            Text('おすすめ度',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _starRating = star),
              child: Icon(
                star <= _starRating ? Icons.star : Icons.star_border,
                size: 32,
                color: Colors.amber,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.map, size: 16, color: Colors.red),
            SizedBox(width: 4),
            Text('位置情報',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        // 主要導線：住所・施設名で検索（Web利用者はほぼこちらを使う想定）
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchLocation(),
                decoration: const InputDecoration(
                  hintText: '店名・施設名・住所で検索',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _searchLocation,
                child: const Text('検索'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // プレビュー地図：確認用。細かい調整は右下ボタンから全画面で行う
        SizedBox(
          width: double.infinity,
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ??
                        LatLng(_selectedCampus.defaultLatitude,
                            _selectedCampus.defaultLongitude),
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _selectedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('pin'),
                            position: _selectedLocation!,
                          ),
                        },
                  onTap: (pos) => setState(() => _selectedLocation = pos),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // 全画面ピッカーを開くボタン（小さい地図でのクリック操作を回避）
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openMapPicker,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full,
                                size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('地図を拡大して調整',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedLocation == null
              ? '住所で検索するか、地図を拡大してピンを置いてください'
              : 'ピンの位置：${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                  '${_selectedLocation!.longitude.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('＋ 投稿する',
                style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// 全画面の地図ピッカー：住所検索と大きな地図でピンを置き、確定した座標を返す。
// フォーム内の小さい地図ではクリックしづらい問題を解消するための画面。
class _MapPickerScreen extends StatefulWidget {
  final MapApiClient mapClient;
  final LatLng initialTarget;
  final LatLng? initialPin;

  const _MapPickerScreen({
    required this.mapClient,
    required this.initialTarget,
    this.initialPin,
  });

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  final _addressController = TextEditingController();
  GoogleMapController? _controller;
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
    try {
      final candidates = await widget.mapClient.searchPlaces(
        query,
        biasLat: widget.initialTarget.latitude,
        biasLng: widget.initialTarget.longitude,
      );
      if (!mounted) return;
      final chosen = candidates.length == 1
          ? candidates.first
          : await showPlaceCandidateSheet(context, candidates);
      if (chosen == null) return;
      final location = LatLng(chosen.latitude, chosen.longitude);
      setState(() => _pin = location);
      await _controller
          ?.animateCamera(CameraUpdate.newLatLngZoom(location, 17));
    } on AddressNotFoundException catch (e) {
      _showSnackBar(e.message);
    } on NetworkException catch (e) {
      _showSnackBar(e.message);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地図で位置を指定')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: '店名・施設名・住所で検索',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _search,
                    child: const Text('検索'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('地図をクリックしてピンを置いてください',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pin ?? widget.initialTarget,
                zoom: 16,
              ),
              onMapCreated: (c) => _controller = c,
              markers: _pin == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('pin'),
                        position: _pin!,
                      ),
                    },
              onTap: (pos) => setState(() => _pin = pos),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed:
                      _pin == null ? null : () => Navigator.pop(context, _pin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('この位置に決定',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
