import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';
import '../auth/token_storage.dart';
import '../models/directions_models.dart';

class DirectionsApiException implements Exception {
  DirectionsApiException({
    required this.statusCode,
    required this.uri,
    this.body,
  });

  final int statusCode;
  final Uri uri;
  final String? body;

  String get userMessage {
    return switch (statusCode) {
      401 => '로그인이 필요합니다.',
      403 => '권한이 없습니다.',
      404 => '서버에서 길찾기 API를 찾을 수 없습니다.',
      408 => '요청 시간이 초과되었습니다.',
      429 => '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
      _ => '경로 요청에 실패했습니다. ($statusCode)',
    };
  }

  String _shortBody({int maxLength = 200}) {
    final raw = body;
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  @override
  String toString() {
    final shortBody = _shortBody();
    if (shortBody.isEmpty) return 'DirectionsApiException($statusCode) ${uri.path}';
    return 'DirectionsApiException($statusCode) ${uri.path}: $shortBody';
  }
}

class DirectionsApiService {
  DirectionsApiService({required this.baseUrl});

  final String baseUrl;

  Future<DirectionsResult> fetchDirections({
    required double startLat,
    required double startLng,
    required double goalLat,
    required double goalLng,
    String option = 'trafast',
  }) async {
    final normalized =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    final queryParams = <String, String>{
      'startLat': startLat.toString(),
      'startLng': startLng.toString(),
      'goalLat': goalLat.toString(),
      'goalLng': goalLng.toString(),
      if (option.trim().isNotEmpty) 'option': option.trim(),
    };

    final endpoints = <Uri>[
      Uri.parse('$normalized/mapi/directions').replace(queryParameters: queryParams),
      Uri.parse('$normalized/mapi/direction').replace(queryParameters: queryParams),
    ];

    bool refreshAttempted = false;
    DirectionsApiException? last404;

    for (final uri in endpoints) {
      http.Response response = await _getWithAuth(uri);

      if (response.statusCode == 401 && !refreshAttempted) {
        refreshAttempted = true;
        try {
          await AuthApi.refreshTokens();
          response = await _getWithAuth(uri);
        } catch (_) {
          // refresh 실패 시 아래에서 예외 처리
        }
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return DirectionsResult.fromJson(decoded);
        }
        throw Exception('unexpected directions response: ${decoded.runtimeType}');
      }

      if (response.statusCode == 404) {
        last404 = DirectionsApiException(
          statusCode: response.statusCode,
          uri: uri,
          body: response.body,
        );
        continue;
      }

      throw DirectionsApiException(
        statusCode: response.statusCode,
        uri: uri,
        body: response.body,
      );
    }

    throw last404 ??
        DirectionsApiException(
          statusCode: 404,
          uri: endpoints.first,
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
}
