import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/welcom.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 추가

void main() {
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ??'', // .env나 dart-define으로 숨겨두면 더 좋음
    javaScriptAppKey:dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ??'',
  );
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
