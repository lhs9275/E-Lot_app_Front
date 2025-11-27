import 'dart:convert';
import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';
import '../auth/token_storage.dart';
import '../models/parking_lot.dart';

late final ParkingLotApiService parkingLotApi;

void configureParkingLotApi({required String baseUrl}) {
  parkingLotApi = ParkingLotApiService(baseUrl: baseUrl);
}

class ParkingLotApiService {
  ParkingLotApiService({required this.baseUrl});

  final String baseUrl;

  Future<List<ParkingLot>> fetchNearby({
    required double lat,
    required double lng,
    double radiusKm = 3,
    int page = 0,
    int size = 200,
  }) async {
    final uri = _buildNearbyUri(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      page: page,
      size: size,
    );
    return _sendAndParse(uri);
  }

  Future<List<ParkingLot>> fetchAll({
    int page = 0,
    int size = 200,
  }) async {
    final uri = _buildSearchUri(
      page: page,
      size: size,
    );
    return _sendAndParse(uri);
  }

  Future<List<ParkingLot>> search({
    String? name,
    String? address,
    int page = 0,
    int size = 200,
  }) async {
    final uri = _buildSearchUri(
      name: name,
      address: address,
      page: page,
      size: size,
    );
    return _sendAndParse(uri);
  }

  Future<List<ParkingLot>> _sendAndParse(Uri uri) async {
    http.Response response = await _getWithAuth(uri);

    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(uri);
      } catch (e) {
        // refresh 실패 시 아래에서 에러 처리
      }
    }

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final items = _extractList(decoded);
      return items
          .map((e) => ParkingLot.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(
      '주차장 정보를 불러오지 못했습니다: ${response.statusCode} ${response.body}',
    );
  }

  Future<http.Response> _getWithAuth(Uri uri) async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http.get(uri, headers: headers);
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final content = decoded['content'];
      if (content is List) return content;
    }
    return const [];
  }

  Uri _buildNearbyUri({
    required double lat,
    required double lng,
    required double radiusKm,
    required int page,
    required int size,
  }) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase/mapi/parking-lots/nearby').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radiusKm': radiusKm.toString(),
        'page': page.toString(),
        'size': size.toString(),
      },
    );
  }

  Uri _buildSearchUri({
    String? name,
    String? address,
    required int page,
    required int size,
  }) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (address != null && address.isNotEmpty) params['address'] = address;

    return Uri.parse('$normalizedBase/mapi/parking-lots').replace(
      queryParameters: params,
    );
  }
}
