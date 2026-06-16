import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/exceptions.dart';

// google_maps_flutter の GeoLocation との衝突を避けるため GeoLocation と命名
class GeoLocation {
  final double latitude;
  final double longitude;

  const GeoLocation(this.latitude, this.longitude);
}

class MapApiClient {
  final String apiKey;
  final http.Client _httpClient;

  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  MapApiClient({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

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
