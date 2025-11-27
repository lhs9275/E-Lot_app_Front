// lib/services/h2_station_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ev_station.dart';
import '../auth/token_storage.dart';
import '../auth/auth_api.dart';

late final EVStationApiService evStationApi;

void configureEVStationApi({required String baseUrl}) {
  evStationApi = EVStationApiService(baseUrl: baseUrl);
}

class EVStationApiService {
  final String baseUrl;

  EVStationApiService({required this.baseUrl});

  Future<List<EVStation>> fetchStations() async {
    final url = _buildStationsUri();
    http.Response response = await _getWithAuth(url);

    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(url);
      } catch (_) {
        // refresh 실패 시 아래에서 예외 처리
      }
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((e) => EVStation.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('충전소 정보를 불러오지 못했습니다: ${response.statusCode}');
    }
  }

  Future<http.Response> _getWithAuth(Uri url) async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http.get(url, headers: headers);
  }

  Uri _buildStationsUri() {
    final normalized =
    baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalized/mapi/ev/stations?type=all');
  }
}
