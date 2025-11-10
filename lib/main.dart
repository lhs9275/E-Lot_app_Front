import 'dart:io' show HttpOverrides, HttpClient, SecurityContext;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/welcom.dart';
import 'services/h2_station_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env 로드 (여기서 꼭 await!)
  await dotenv.load(fileName: ".env");

  // 2. 개발 환경에서만 자체 서명 인증서 허용
  _configureHttpOverrides();

  // 3. H2 API 서비스 구성 (환경 변수 없으면 기본값)
  configureH2StationApi(baseUrl: _resolveH2BaseUrl());

  // 4. 로드된 값으로 KakaoSdk 초기화
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? '',
    // 또는 dotenv.get('KAKAO_NATIVE_APP_KEY') 써도 됨 (없으면 에러 던짐)
  );

  // 5. 앱 실행
  runApp(const MyApp());
}

String _resolveH2BaseUrl() {
  final value = dotenv.env['H2_API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) {
    const fallback = 'http://10.0.2.2:8443';
    debugPrint(
      '[H2 API] H2_API_BASE_URL가 설정되지 않아 기본값($fallback)을 사용합니다. 실제 서버 주소를 .env에 설정하세요.',
    );
    return fallback;
  }
  return value;
}

void _configureHttpOverrides() {
  if (kIsWeb || !_shouldAllowInsecureSsl()) return;
  HttpOverrides.global = _InsecureHttpOverrides();
  debugPrint(
    '[H2 API] 자체 서명 인증서를 허용하도록 HttpOverrides를 적용했습니다. 배포 빌드에서는 비활성화하세요.',
  );
}

bool _shouldAllowInsecureSsl() {
  final value = dotenv.env['H2_API_ALLOW_INSECURE_SSL'];
  if (value == null) return false;
  final normalized = value.trim().toLowerCase();
  return {'true', '1', 'yes', 'y'}.contains(normalized);
}

class _InsecureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, __, ___) => true;
    return client;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSP2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
