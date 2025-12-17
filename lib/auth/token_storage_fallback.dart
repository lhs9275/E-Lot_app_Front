import 'token_storage_interface.dart';

/// Web/Wasm용 단순 인메모리 저장소.
/// 새로고침 시 토큰이 초기화되므로 서버 세션 기반 로그인 상태가 필요하다면
/// 별도 처리(예: 재로그인)가 필요하다.
TokenStorageImpl createTokenStorage() => _InMemoryTokenStorage();

class _InMemoryTokenStorage implements TokenStorageImpl {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
