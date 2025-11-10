import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/welcom.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env 로드 (여기서 꼭 await!)
  await dotenv.load(fileName: ".env");

  // 2. 로드된 값으로 KakaoSdk 초기화
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? '',
    // 또는 dotenv.get('KAKAO_NATIVE_APP_KEY') 써도 됨 (없으면 에러 던짐)
  );

  // 3. 앱 실행
  runApp(const MyApp());
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