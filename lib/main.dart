import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/welcom.dart';

void main() {
  KakaoSdk.init(
    nativeAppKey: 'd480d92012b558a0f40dbebbf3a17519', // .env나 dart-define으로 숨겨두면 더 좋음
    javaScriptAppKey: 'f10081a6b592d61a653e809d9c7acd2c',
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
