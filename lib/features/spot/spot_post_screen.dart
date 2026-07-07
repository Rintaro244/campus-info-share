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
  List<XFile> _selectedImages = [];
  LatLng? _selectedLocation;
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

  Future<void> _geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    try {
      final result = await _mapClient.geocode(address);
      setState(() => _selectedLocation = LatLng(result.latitude, result.longitude));
    } on AddressNotFoundException catch (e) {
      _showSnackBar(e.message);
    } on NetworkException catch (e) {
      _showSnackBar(e.message);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showSnackBar('写真を1枚以上選択してください');
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
      appBar: AppBar(title: const Text('Spot投稿')),
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
          onPressed: (i) =>
              setState(() => _selectedCampus = Campus.values[i]),
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  hintText: '住所を入力して検索',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _geocodeAddress,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _selectedLocation != null
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: _selectedLocation!, zoom: 15),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pin'),
                        position: _selectedLocation!,
                      ),
                    },
                    onTap: (pos) =>
                        setState(() => _selectedLocation = pos),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  )
                : Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: Text('[ GoogleMap ピン配置 ]',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
          ),
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
