import 'dart:io' show HttpOverrides, HttpClient, SecurityContext;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/welcom.dart';
import 'services/h2_station_api_service.dart';
import 'services/ev_station_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env ë¡œë“œ (?¬ê¸°??ê¼?await!)
  await dotenv.load(fileName: ".env");

  // 2. ê°œë°œ ?˜ê²½?ì„œë§??ì²´ ?œëª… ?¸ì¦???ˆìš©
  _configureHttpOverrides();

  // 3. H2 API ?œë¹„??êµ¬ì„± (?˜ê²½ ë³€???†ìœ¼ë©?ê¸°ë³¸ê°?
  configureH2StationApi(baseUrl: _resolveH2BaseUrl());
  // EV API??ë¡œì»¬ ê°œë°œ??ë³„ë„ ë² ì´??URL ?¬ìš©(.env??EV_API_BASE_URL ?¤ì •)
  configureEVStationApi(baseUrl: _resolveEvBaseUrl());

  // 4. ?¤ì´ë²?ì§€??SDK ì´ˆê¸°??
  await _initializeNaverMap();

  // 5. ë¡œë“œ??ê°’ìœ¼ë¡?KakaoSdk ì´ˆê¸°??
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? '',
    // ?ëŠ” dotenv.get('KAKAO_NATIVE_APP_KEY') ?¨ë„ ??(?†ìœ¼ë©??ëŸ¬ ?˜ì§)
  );

  // 6. ???¤í–‰
  runApp(const MyApp());
}

String _resolveH2BaseUrl() {
  final value = dotenv.env['H2_API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) {
    const fallback = 'https://clos21.kr';
    debugPrint(
      '[H2 API] H2_API_BASE_URLê°€ ?¤ì •?˜ì? ?Šì•„ ê¸°ë³¸ê°?$fallback)???¬ìš©?©ë‹ˆ?? ?¤ì œ ?œë²„ ì£¼ì†Œë¥?.env???¤ì •?˜ì„¸??',
    );
    return fallback;
  }
  return value;
}

String _resolveEvBaseUrl() {
  final value = dotenv.env['EV_API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) {
    // ?ë??ˆì´???¤ê¸°ê¸°ì—??ë¡œì»¬?¸ìŠ¤?¸ë¡œ ?‘ì†????ê¸°ë³¸ê°??ˆë“œë¡œì´?œëŠ” 10.0.2.2)
    const fallback = 'http://10.0.2.2:8080';
    debugPrint(
      '[EV API] EV_API_BASE_URLê°€ ?¤ì •?˜ì? ?Šì•„ ê¸°ë³¸ê°?$fallback)???¬ìš©?©ë‹ˆ?? ë¡œì»¬ ?œë²„ ì£¼ì†Œë¥?.env???¤ì •?˜ì„¸??',
    );
    return fallback;
  }
  return value;
}

void _configureHttpOverrides() {
  if (kIsWeb || !_shouldAllowInsecureSsl()) return;
  HttpOverrides.global = _InsecureHttpOverrides();
  debugPrint(
    '[H2 API] ?ì²´ ?œëª… ?¸ì¦?œë? ?ˆìš©?˜ë„ë¡?HttpOverridesë¥??ìš©?ˆìŠµ?ˆë‹¤. ë°°í¬ ë¹Œë“œ?ì„œ??ë¹„í™œ?±í™”?˜ì„¸??',
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
          debugPrint('[NaverMap] ?¸ì¦ ?¤íŒ¨ (code: ${ex.code}): ${ex.message}'),
    );
  } catch (error) {
    debugPrint(
      '[NaverMap] ì´ˆê¸°???¤íŒ¨: $error ??.env??NAVER_MAP_CLIENT_IDë¥??¤ì •?ˆëŠ”ì§€ ?•ì¸?˜ì„¸??',
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
