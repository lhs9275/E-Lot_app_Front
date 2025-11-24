import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'token_storage.dart';

class AuthApi {
  static const String _baseUrl = 'https://clos21.kr';

  /// 1. 카카오 로그인 → accessToken 얻고
  /// 2. clos21 /mapi/auth/kakao 로 교환
  static Future<void> loginWithKakao() async {
    try {
      // 1. 카카오 로그인 (톡 우선)
      OAuthToken token;
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        // 카카오톡 없거나 실패하면 계정 로그인
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 2. Clos21 백엔드로 accessToken 전달
      final response = await http.post(
        Uri.parse('$_baseUrl/mapi/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kakaoAccessToken': token.accessToken}),
      );

      developer.log(
        '[/mapi/auth/kakao] response ${response.statusCode}: ${response.body}',
        name: 'AuthApi',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        developer.log(
          '[/mapi/auth/kakao] issued tokens '
              'access=${_previewToken(accessToken)} '
              'refresh=${_previewToken(refreshToken)}',
          name: 'AuthApi',
        );

        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        // 서버에서 401 등 에러 내려줄 때
        throw Exception(
          'Clos21 login failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  static String _previewToken(String token) {
    if (token.length <= 10) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  /// refresh 토큰으로 새 JWT 발급
  static Future<void> refreshTokens() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/mapi/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final accessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;

      await TokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
    } else {
      // refresh 실패 → 강제 로그아웃 플로우
      await TokenStorage.clear();
      throw Exception(
        'Refresh failed: ${response.statusCode} ${response.body}',
      );
    }
  }
}
