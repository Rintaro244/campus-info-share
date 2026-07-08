import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/exceptions.dart';

// google_maps_flutter の GeoLocation との衝突を避けるため GeoLocation と命名
class GeoLocation {
  final double latitude;
  final double longitude;

  const GeoLocation(this.latitude, this.longitude);
}

// 場所検索（Places Text Search）の候補1件。店名・住所・座標を持つ。
class PlaceCandidate {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceCandidate({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class MapApiClient {
  final String apiKey;
  final http.Client _httpClient;

  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  // Places API (New) の Text Search。ブラウザからのCORSに対応している。
  static const String _placesSearchUrl =
      'https://places.googleapis.com/v1/places:searchText';

  MapApiClient({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// 店名・キーワードの部分入力から場所の候補を検索する（Places Text Search）。
  /// 住所の完全一致を要求する geocode と違い「つじ田」等の曖昧な店名でヒットする。
  /// biasLat/biasLng を渡すとその周辺（キャンパス等）の結果を優先する。
  Future<List<PlaceCandidate>> searchPlaces(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async {
    final requestBody = <String, dynamic>{
      'textQuery': query,
      'languageCode': 'ja',
      'regionCode': 'JP',
      if (biasLat != null && biasLng != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': biasLat, 'longitude': biasLng},
            'radius': 30000.0,
          },
        },
    };

    // キーはヘッダー(X-Goog-Api-Key)ではなくクエリで渡す。
    // ブラウザ(Web)からのCORSリクエストではヘッダー方式のキーが認識されず
    // 403「unregistered callers」になるため、geocodeと同じクエリ方式に揃える。
    final uri = Uri.parse(_placesSearchUrl).replace(queryParameters: {
      'key': apiKey,
      // 必要なフィールドだけ取得（課金・レスポンス削減のため必須）
      'fields': 'places.displayName,places.formattedAddress,places.location',
    });

    try {
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw NetworkException('場所検索APIへの接続に失敗しました (${response.statusCode})');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final places = body['places'] as List<dynamic>?;
      if (places == null || places.isEmpty) {
        throw AddressNotFoundException('「$query」に一致する場所が見つかりません');
      }

      return places.map((p) {
        final place = p as Map<String, dynamic>;
        final location = place['location'] as Map<String, dynamic>;
        final displayName = place['displayName'] as Map<String, dynamic>?;
        return PlaceCandidate(
          name: (displayName?['text'] as String?) ?? '（名称不明）',
          address: (place['formattedAddress'] as String?) ?? '',
          latitude: (location['latitude'] as num).toDouble(),
          longitude: (location['longitude'] as num).toDouble(),
        );
      }).toList();
    } on AddressNotFoundException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('通信環境を確認してください');
    }
  }

  /// 住所文字列から緯度・経度を取得する（ジオコーディング）。
  Future<GeoLocation> geocode(String address) async {
    final uri = Uri.parse(_geocodeBaseUrl).replace(queryParameters: {
      'address': address,
      'key': apiKey,
      'language': 'ja',
    });

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        throw NetworkException('ジオコーディングAPIへの接続に失敗しました (${response.statusCode})');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String;

      switch (status) {
        case 'OK':
          final location =
              body['results'][0]['geometry']['location'] as Map<String, dynamic>;
          return GeoLocation(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          );
        case 'ZERO_RESULTS':
          throw AddressNotFoundException('「$address」の座標が見つかりません');
        case 'OVER_QUERY_LIMIT':
        case 'OVER_DAILY_LIMIT':
          throw QuotaExceededException();
        default:
          throw NetworkException('ジオコーディングに失敗しました: $status');
      }
    } on AddressNotFoundException {
      rethrow;
    } on QuotaExceededException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('通信環境を確認してください');
    }
  }

  /// 緯度・経度から住所文字列を取得する（逆ジオコーディング）。
  Future<String> reverseGeocode(double latitude, double longitude) async {
    final uri = Uri.parse(_geocodeBaseUrl).replace(queryParameters: {
      'latlng': '$latitude,$longitude',
      'key': apiKey,
      'language': 'ja',
    });

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        throw NetworkException('逆ジオコーディングAPIへの接続に失敗しました (${response.statusCode})');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String;

      switch (status) {
        case 'OK':
          return body['results'][0]['formatted_address'] as String;
        case 'ZERO_RESULTS':
          throw AddressNotFoundException('この座標に対応する住所が見つかりません');
        case 'OVER_QUERY_LIMIT':
        case 'OVER_DAILY_LIMIT':
          throw QuotaExceededException();
        default:
          throw NetworkException('逆ジオコーディングに失敗しました: $status');
      }
    } on AddressNotFoundException {
      rethrow;
    } on QuotaExceededException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('通信環境を確認してください');
    }
  }

  void dispose() => _httpClient.close();
}
