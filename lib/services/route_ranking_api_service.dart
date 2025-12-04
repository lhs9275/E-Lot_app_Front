import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';
import '../auth/auth_api.dart';
import '../models/route_ranking_models.dart';

class RouteRankingApiService {
  RouteRankingApiService({required this.baseUrl});

  final String baseUrl;

  Future<RouteRankingResponse> fetchRankings({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    double radiusKm = 5,
    bool includeEv = true,
    bool includeH2 = true,
    bool includeParking = true,
    String preset = 'BALANCED',
    int limit = 10,
    // Optional filters (same as nearby)
    String? evType,
    String? evChargerType,
    String? evStatus,
    String? h2Type,
    String? stationTypeCsv,
    String? specCsv,
    int? priceMin,
    int? priceMax,
    int? availableMin,
    String? parkingCategory,
    String? parkingFeeType,
  }) async {
    final params = <String, String>{
      'startLat': startLat.toString(),
      'startLng': startLng.toString(),
      'endLat': endLat.toString(),
      'endLng': endLng.toString(),
      'radiusKm': radiusKm.toString(),
      'includeEv': includeEv.toString(),
      'includeH2': includeH2.toString(),
      'includeParking': includeParking.toString(),
      'preset': preset,
      'limit': limit.toString(),
    };

    void addIfPresent(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    void addInt(String key, int? value) {
      if (value != null) {
        params[key] = value.toString();
      }
    }

    addIfPresent('evType', evType);
    addIfPresent('evChargerType', evChargerType);
    addIfPresent('evStatus', evStatus);
    addIfPresent('h2Type', h2Type);
    addIfPresent('stationType', stationTypeCsv);
    addIfPresent('spec', specCsv);
    addInt('priceMin', priceMin);
    addInt('priceMax', priceMax);
    addInt('availableMin', availableMin);
    addIfPresent('parkingCategory', parkingCategory);
    addIfPresent('parkingFeeType', parkingFeeType);

    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$normalizedBase/mapi/rank')
        .replace(queryParameters: params);

    http.Response response = await _getWithAuth(uri);

    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(uri);
      } catch (_) {
        // refresh 실패 시 아래에서 예외 처리
      }
    }

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return RouteRankingResponse.fromJson(decoded);
    }

    throw Exception('rank fetch failed: ${response.statusCode} ${response.body}');
  }

  Future<http.Response> _getWithAuth(Uri uri) async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http.get(uri, headers: headers);
  }
}
