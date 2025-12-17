import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage_interface.dart';

TokenStorageImpl createTokenStorage() => _SecureStorageTokenStorage();

class _SecureStorageTokenStorage implements TokenStorageImpl {
  static const _keyAccessToken = 'clos21_access_token';
  static const _keyRefreshToken = 'clos21_refresh_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  @override
  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }
}
