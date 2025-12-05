// lib/services/h2_station_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_api.dart';
import '../auth/token_storage.dart';
import '../models/h2_station.dart';

late final H2StationApiService h2StationApi;

void configureH2StationApi({required String baseUrl}) {
  h2StationApi = H2StationApiService(baseUrl: baseUrl);
}

class H2StationApiService {
  final String baseUrl;

  H2StationApiService({required this.baseUrl});

  Future<List<H2Station>> fetchStations() async {
    final url = _buildStationsUri();
    final headers = await _buildAuthHeaders();
    http.Response response = await http.get(url, headers: headers);

    // access token 만료 시 1회 재시도
    if (response.statusCode == 401) {
      final refreshed = await _refreshAccessToken(headers);
      if (refreshed) {
        response = await http.get(url, headers: headers);
      }
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((e) => H2Station.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('충전소 정보를 불러오지 못했습니다: ${response.statusCode}');
    }
  }

  Future<Map<String, String>> _buildAuthHeaders() async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{};

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<bool> _refreshAccessToken(Map<String, String> headers) async {
    try {
      await AuthApi.refreshTokens();
      final newToken = await TokenStorage.getAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $newToken';
        return true;
      }
    } catch (_) {
      // 갱신 실패 시 false 반환하여 기존 응답을 그대로 처리
    }
    return false;
  }

  Uri _buildStationsUri() {
    final normalized =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalized/mapi/h2/stations?type=all');
  }
}
