import 'token_storage_interface.dart';
import 'token_storage_fallback.dart'
    if (dart.library.io) 'token_storage_io.dart' as impl;

/// 토큰 저장/조회/삭제를 플랫폼별 구현에 위임한다.
class TokenStorage {
  static final TokenStorageImpl _delegate = impl.createTokenStorage();

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) =>
      _delegate.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  static Future<String?> getAccessToken() => _delegate.getAccessToken();

  static Future<String?> getRefreshToken() => _delegate.getRefreshToken();

  static Future<void> clear() => _delegate.clear();
}
