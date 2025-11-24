import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'auth_api.dart';

class AuthHttpClient {
  static const String _baseUrl = 'https://clos21.kr';

  /// GET 예시
  static Future<http.Response> get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send((headers) => http.get(uri, headers: headers));
  }

  /// 본문 없이 POST
  static Future<http.Response> post(String path) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send((headers) => http.post(uri, headers: headers));
  }

  /// POST 예시 (JSON body)
  static Future<http.Response> postJson(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      (headers) => http.post(
        uri,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  /// DELETE 예시
  static Future<http.Response> delete(String path) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send((headers) => http.delete(uri, headers: headers));
  }

  /// 공통 요청 처리 + 401 시 refresh
  static Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var accessToken = await TokenStorage.getAccessToken();

    // 1차 시도
    var response = await requestFn(_authHeaders(accessToken));

    // 401이면 refresh 시도 후 한 번 더
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        accessToken = await TokenStorage.getAccessToken();
      } catch (_) {
        // refresh 실패 시 원본 응답을 그대로 돌려준다.
        return response;
      }
      response = await requestFn(_authHeaders(accessToken));
    }

    return response;
  }

  static Map<String, String> _authHeaders(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) return {};
    return {'Authorization': 'Bearer $accessToken'};
  }
}
