import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:psp2_fn/auth/token_storage.dart';
import 'package:psp2_fn/screens/map.dart';


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleKakaoLogin(BuildContext context) async {
    try {
      // 1. 카카오 로그인 (카카오톡 우선, 실패 시 계정 로그인)
      OAuthToken kakaoToken;
      try {
        kakaoToken = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }

      // 2. Clos21 백엔드로 카카오 accessToken 전달
      final response = await http.post(
        Uri.parse('https://clos21.kr/mapi/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kakaoAccessToken': kakaoToken.accessToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        if (accessToken == null || refreshToken == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서버 응답에 토큰 정보가 없습니다.')),
          );
          return;
        }

        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (!context.mounted) return;

        // 로그인 성공 → 홈 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        if (!context.mounted) return;
        // 서버 에러 메시지 출력
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '로그인 실패 (${response.statusCode}): ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카카오 로그인 중 오류: $e')),
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
              Color.fromRGBO(255, 255, 255, 1.0), // 파란색
              Color.fromRGBO(255, 255, 255, 1.0), // 조금 더 진한 파란색
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
                  height: 0, // 위쪽 영역 높이
                  child: Stack(
                    clipBehavior: Clip.none, // 살짝 화면 밖으로 나가도 괜찮게
                    children: [
                      // 왼쪽 위치 아이콘
                      Positioned(
                        left: 0,
                        top: 80, // 숫자 튜닝해서 내려주면 됨
                        child: SvgPicture.asset(
                          'lib/assets/icons/welcome_sc/location_icon.svg',
                          width: 200,
                          height: 200,
                        ),
                      ),

                      // 오른쪽 위 초록 블러
                      Positioned(
                        right: -100, // 살짝 밖으로 나가게
                        top: -100,
                        child: Image.asset(
                          'lib/assets/icons/welcome_sc/blusher_green.png',
                          width: 400,
                          height: 400,
                        ),
                      ),

                      // 왼쪽 아래 파란 블러
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
                  '세상을 E-Lot게 하다',
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
                // 버튼 영역
                SizedBox(
                  child: Positioned(
                    left: 0,
                    top: 0, // 숫자 튜닝해서 내려주면 됨
                    child: SvgPicture.asset(
                      'lib/assets/icons/welcome_sc/cute_under_bar.svg',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ), //
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
