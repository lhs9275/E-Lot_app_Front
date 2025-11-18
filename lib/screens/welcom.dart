import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:psp2_fn/auth/token_storage.dart';
import 'package:psp2_fn/screens/map.dart';


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleKakaoLogin(BuildContext context) async {
    debugPrint('카카오 로그인 시작');
    try {
      // 1. 카카??로그??(카카?�톡 ?�선, ?�패 ??계정 로그??
      OAuthToken kakaoToken;
      try {
        debugPrint('loginWithKakaoTalk 시도');
        kakaoToken = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        debugPrint('카카오톡 로그인 실패, 계정 로그인 시도');
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }

      debugPrint('백엔드 요청 전송');
      // 2. Clos21 백엔?�로 카카??accessToken ?�달
      final response = await http.post(
        Uri.parse('https://clos21.kr/mapi/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kakaoAccessToken': kakaoToken.accessToken}),
      );

      debugPrint('백엔드 응답: ${response.statusCode} / ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        if (accessToken == null || refreshToken == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('?�버 ?�답???�큰 ?�보가 ?�습?�다.')),
          );
          return;
        }

        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (!context.mounted) return;

        // 로그???�공 ?????�면?�로 ?�동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        debugPrint('로그인 실패 상태 코드: ${response.statusCode}');
        if (!context.mounted) return;
        // ?�버 ?�러 메시지 출력
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '로그???�패 (${response.statusCode}): ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('카카오 로그인 예외: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카카??로그??�??�류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(255, 255, 255, 1.0), // ?��???
              Color.fromRGBO(255, 255, 255, 1.0), // 조금 ??진한 ?��???
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 0, // ?�쪽 ?�역 ?�이
                  child: Stack(
                    clipBehavior: Clip.none, // ?�짝 ?�면 밖으�??��???괜찮�?
                    children: [
                      // ?�쪽 ?�치 ?�이�?
                      Positioned(
                        left: 0,
                        top: 80, // ?�자 ?�닝?�서 ?�려주면 ??
                        child: SvgPicture.asset(
                          'lib/assets/icons/welcome_sc/location_icon.svg',
                          width: 200,
                          height: 200,
                        ),
                      ),

                      // ?�른�???초록 블러
                      Positioned(
                        right: -100, // ?�짝 밖으�??��?�?
                        top: -100,
                        child: Image.asset(
                          'lib/assets/icons/welcome_sc/blusher_green.png',
                          width: 400,
                          height: 400,
                        ),
                      ),

                      // ?�쪽 ?�래 ?��? 블러
                      Positioned(
                        left: -120,
                        bottom: -560,
                        child: Image.asset(
                          'lib/assets/icons/welcome_sc/blusher_blue.png',
                          width: 400,
                          height: 400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Spacer(),
                Text(
                  '?�상??E-Lot�??�다',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'E-lot',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                // 버튼 ?�역
                SizedBox(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SvgPicture.asset(
                      'lib/assets/icons/welcome_sc/cute_under_bar.svg',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _handleKakaoLogin(context),
                    child: Image.asset(
                      'lib/assets/icons/welcome_sc/kakao_login_medium_wide.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

