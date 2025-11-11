import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'auth_api.dart';

class AuthHttpClient {
  static const String _baseUrl = 'https://clos21.kr';

  /// GET 예시
  static Future<http.Response> get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(() => http.get(uri, headers: {}));
  }

  /// POST 예시 (JSON body)
  static Future<http.Response> postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
          () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  /// 공통 요청 처리 + 401 시 refresh
  static Future<http.Response> _send(
      Future<http.Response> Function() requestFn,
      ) async {
    String? accessToken = await TokenStorage.getAccessToken();

    // 1차 시도
    var response = await _requestWithAuthHeader(requestFn, accessToken);

    // 401이면 refresh 시도 후 한 번 더
    if (response.statusCode == 401) {
      await AuthApi.refreshTokens();
      accessToken = await TokenStorage.getAccessToken();
      response = await _requestWithAuthHeader(requestFn, accessToken);
    }

    return response;
  }

  static Future<http.Response> _requestWithAuthHeader(
      Future<http.Response> Function() requestFn,
      String? accessToken,
      ) async {
    // 여기선 http.Request를 직접 쓰거나, requestFn에 headers를 인자로 넘기는 방식으로
    // 더 깔끔하게 할 수 있는데,
    // 사용 패턴에 따라 구조 조금 손봐야 해서, 패턴 정하면 거기에 맞춰 리팩토링해도 됨.
    // 우선은 간단한 예시로, 각 API 쪽에서 headers에 accessToken을 집어넣는 구조로 쓰는 게 더 나음.
    return requestFn();
  }
}
