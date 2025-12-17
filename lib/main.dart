import 'dart:io' show HttpOverrides, HttpClient, SecurityContext;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/etc/ranking.dart';
import 'services/h2_station_api_service.dart';
import 'services/ev_station_api_service.dart';
import 'services/parking_lot_api_service.dart';
import 'services/reservation_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env 로드 (여기서 꼭 await!)
  await dotenv.load(fileName: ".env");
  final kakaoNativeAppKey = dotenv.env['KAKAO_NATIVE_APP_KEY']?.trim();
  final kakaoJavaScriptAppKey =
      dotenv.env['KAKAO_JAVASCRIPT_APP_KEY']?.trim();

  final missingKakaoKeys = <String>[];
  if (kakaoNativeAppKey == null || kakaoNativeAppKey.isEmpty) {
    missingKakaoKeys.add('KAKAO_NATIVE_APP_KEY');
  }
  if (kakaoJavaScriptAppKey == null || kakaoJavaScriptAppKey.isEmpty) {
    missingKakaoKeys.add('KAKAO_JAVASCRIPT_APP_KEY');
  }

  final kakaoConfigError = missingKakaoKeys.isEmpty
      ? null
      : '카카오 SDK 키 누락: ${missingKakaoKeys.join(', ')} — 프로젝트 루트의 .env를 확인하세요.';

  // 2. 개발 환경에서만 자체 서명 인증서 허용
  _configureHttpOverrides();

  // 3. H2 API 서비스 구성 (환경 변수 없으면 기본값)
  configureH2StationApi(baseUrl: _resolveH2BaseUrl());
  // EV API는 로컬 개발용 별도 베이스 URL 사용(.env에 EV_API_BASE_URL 설정)
  configureEVStationApi(baseUrl: _resolveEvBaseUrl());
  // Parking API 구성 (미설정 시 EV와 동일 서버로 시도)
  configureParkingLotApi(baseUrl: _resolveParkingBaseUrl());
  // Reservation/Payment API 구성 (미설정 시 clos21 기본값)
  configureReservationApi(baseUrl: _resolveBackendBaseUrl());

  debugPrint('NAVER CLIENT: ${dotenv.env['NAVER_MAP_CLIENT_ID']}');
  // 4. 네이버 지도 SDK 초기화
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNaverMap();

  // 5. 로드된 값으로 KakaoSdk 초기화
  if (missingKakaoKeys.isEmpty) {
    KakaoSdk.init(
      nativeAppKey: kakaoNativeAppKey!,
      javaScriptAppKey: kakaoJavaScriptAppKey!,
      // 또는 dotenv.get('KAKAO_NATIVE_APP_KEY') 써도 됨 (없으면 에러 던짐)
    );
  } else {
    debugPrint('[KakaoSdk] 초기화를 건너뜁니다: $kakaoConfigError');
  }

  // 6. 앱 실행
  runApp(
    MyApp(
      isKakaoConfigured: missingKakaoKeys.isEmpty,
      kakaoConfigError: kakaoConfigError,
    ),
  );
}

String _resolveH2BaseUrl() {
  final value = dotenv.env['H2_API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) {
    const fallback = 'https://clos21.kr';
    debugPrint(
      '[H2 API] H2_API_BASE_URL가 설정되지 않아 기본값($fallback)을 사용합니다. 실제 서버 주소를 .env에 설정하세요.',
    );
    return fallback;
  }
  return value;
}

String _resolveEvBaseUrl() {
  final value = dotenv.env['EV_API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) {
    // 에뮬레이터/실기기에서 로컬호스트로 접속할 때 기본값(안드로이드는 10.0.2.2)
    const fallback = 'http://10.0.2.2:8080';
    debugPrint(
      '[EV API] EV_API_BASE_URL가 설정되지 않아 기본값($fallback)을 사용합니다. 로컬 서버 주소를 .env에 설정하세요.',
    );
    return fallback;
  }
  return value;
}

String _resolveParkingBaseUrl() {
  final value = dotenv.env['PARKING_API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) {
    final evBase = dotenv.env['EV_API_BASE_URL']?.trim();
    final fallback =
        (evBase == null || evBase.isEmpty) ? 'http://10.0.2.2:8080' : evBase;
    debugPrint(
      '[Parking API] PARKING_API_BASE_URL가 없어 EV_API_BASE_URL 또는 기본값($fallback)을 사용합니다.',
    );
    return fallback;
  }
  return value;
}

String _resolveBackendBaseUrl() {
  final explicit = dotenv.env['BACKEND_BASE_URL']?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;

  final h2 = dotenv.env['H2_API_BASE_URL']?.trim();
  if (h2 != null && h2.isNotEmpty) return h2;

  final ev = dotenv.env['EV_API_BASE_URL']?.trim();
  if (ev != null && ev.isNotEmpty) return ev;

  const fallback = 'https://clos21.kr';
  debugPrint(
    '[Backend API] BACKEND_BASE_URL가 없어 기본값($fallback)을 사용합니다.',
  );
  return fallback;
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

Future<void> _initializeNaverMap() async {
  final rawClientId = dotenv.env['NAVER_MAP_CLIENT_ID']?.trim();
  final clientId =
      (rawClientId == null || rawClientId.isEmpty) ? 'hoivm494r9' : rawClientId;

  try {
    await FlutterNaverMap().init(
      clientId: clientId,
      onAuthFailed: (ex) =>
          debugPrint('[NaverMap] 인증 실패 (code: ${ex.code}): ${ex.message}'),
    );
  } catch (error) {
    debugPrint(
      '[NaverMap] 초기화 실패: $error — .env에 NAVER_MAP_CLIENT_ID를 설정했는지 확인하세요.',
    );
  }
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
  const MyApp({
    super.key,
    required this.isKakaoConfigured,
    this.kakaoConfigError,
  });

  final bool isKakaoConfigured;
  final String? kakaoConfigError;

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
      home: WelcomeScreen(
        isKakaoConfigured: isKakaoConfigured,
        kakaoConfigError: kakaoConfigError,
      ),
      routes: {
        '/ranking': (_) => const RankingScreen(),
      },
    );
  }
}
