import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:psp2_fn/auth/token_storage.dart';
import 'package:psp2_fn/screens/map.dart';
import 'package:video_player/video_player.dart'; // [필수] 비디오 패키지

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.isKakaoConfigured,
    this.kakaoConfigError,
  });

  final bool isKakaoConfigured;
  final String? kakaoConfigError;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // [Video] 컨트롤러 선언
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    // [Video] 초기화
    // ★ 수정됨: 경로에서 'lib/'를 제거했습니다. (보통 assets/로 시작해야 함)
    // 만약 그래도 안 되면 파일명이나 경로 오타를 확인해주세요.
    _videoController = VideoPlayerController.asset('lib/assets/icons/welcome_sc/walking_sparky.mp4')
      ..initialize().then((_) {
        // 비디오 로딩이 끝나면 화면 갱신
        setState(() {});
        _videoController.play();      // 자동 재생
        _videoController.setLooping(true); // 반복 재생
      }).catchError((error) {
        debugPrint("비디오 로딩 에러: $error"); // 에러 발생 시 콘솔 출력
      });
  }

  @override
  void dispose() {
    _videoController.dispose(); // 메모리 해제
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // [Logic] 1. 에러 메시지 스낵바 표시
  // ------------------------------------------------------------------------
  void _showKakaoConfigError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.kakaoConfigError ??
              '카카오 SDK 키가 없습니다. .env에 KAKAO_NATIVE_APP_KEY, KAKAO_JAVASCRIPT_APP_KEY를 채워주세요.',
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // [Logic] 2. 카카오 로그인 및 백엔드 통신
  // ------------------------------------------------------------------------
  Future<void> _handleKakaoLogin(BuildContext context) async {
    try {
      if (!widget.isKakaoConfigured) {
        _showKakaoConfigError(context);
        return;
      }

      // 1. 카카오 로그인 시도
      OAuthToken kakaoToken;
      try {
        kakaoToken = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 백엔드로 토큰 전달
      final response = await http.post(
        Uri.parse('https://clos21.kr/mapi/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kakaoAccessToken': kakaoToken.accessToken}),
      );

      developer.log(
        '[/mapi/auth/kakao] response ${response.statusCode}: ${response.body}',
        name: 'WelcomeScreen',
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

        developer.log(
          '[/mapi/auth/kakao] issued tokens '
              'access=${_previewToken(accessToken)} '
              'refresh=${_previewToken(refreshToken)}',
          name: 'WelcomeScreen',
        );

        if (!context.mounted) return;

        // 로그인 성공 -> 지도 화면 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패 (${response.statusCode}): ${response.body}'),
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

  String _previewToken(String token) {
    if (token.length <= 10) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  // ------------------------------------------------------------------------
  // [UI] XML 기반 화면 구현 (Stack + Positioned)
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: 402,
            height: 874,
            child: Stack(
              children: [
                // ========================================================
                // [수정됨] 아이콘들에 BouncingAnimation 적용 완료
                // ========================================================

                // 1. 작은 물방울 (딜레이 0)
                Positioned(
                  left: 110,
                  top: 103,
                  child: BouncingAnimation(
                    delay: 0, // 바로 시작
                    child: Image.asset(
                      'lib/assets/icons/welcome_sc/mini_h2.png',
                      width: 80,
                      height: 70,
                    ),
                  ),
                ),

                // 2. 작은 번개 (딜레이 200ms)
                Positioned(
                  left: 289,
                  top: 132,
                  child: BouncingAnimation(
                    delay: 200, // 엇박자
                    child: Image.asset(
                      'lib/assets/icons/welcome_sc/mini_thunder.png',
                      width: 120,
                      height: 110,
                    ),
                  ),
                ),

                // 3. 큰 번개 (딜레이 400ms)
                Positioned(
                  left: 186,
                  top: 182,
                  child: BouncingAnimation(
                    delay: 400,
                    child: Image.asset(
                      'lib/assets/icons/welcome_sc/mini_thunder.png',
                      width: 120,
                      height: 110,
                    ),
                  ),
                ),

                // 4. 보라색 차 (딜레이 600ms)
                Positioned(
                  left: 14,
                  top: 173,
                  child: BouncingAnimation(
                    delay: 600,
                    child: Image.asset(
                      'lib/assets/icons/welcome_sc/mini_purple_car.png',
                      width: 87.24,
                      height: 76.91,
                    ),
                  ),
                ),

                // ============================================================
                // [Video] 5. 메인 캐릭터 (mp4 영상 재생)
                // ============================================================
                Positioned(
                  left: 50,
                  top: 300,
                  child: SizedBox(
                    width: 301,
                    height: 200,
                    child: _videoController.value.isInitialized
                        ? AspectRatio(
                      aspectRatio: _videoController.value.aspectRatio,
                      child: VideoPlayer(_videoController),
                    )
                        : const Center(
                      // 로딩 중일 때 표시 (노란색 로딩바)
                      child: CircularProgressIndicator(color: Color(0xFFFEE500)),
                    ),
                  ),
                ),
                // ============================================================

                // 6. Subtitle: "세상을 E-Lot게 하다"
                const Positioned(
                  left: 28,
                  top: 580,
                  child: Text(
                    "세상을 E-Lot게 하다",
                    style: TextStyle(
                      fontFamily: 'lib/assets/fonts/NotoSansKR-Medium.ttf',
                      fontSize: 20,
                      color: Color(0xFF000000),
                      height: 1.1,
                    ),
                  ),
                ),

                // 7. Title: "E-Lot"
                const Positioned(
                  left: 28,
                  top: 615,
                  child: Text(
                    "E-Lot",
                    style: TextStyle(
                      fontFamily: 'lib/assets/fonts/NotoSansKR-Bold.ttf',
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                      letterSpacing: -0.01,
                    ),
                  ),
                ),

                // [Logic UI] 카카오 설정 에러 메시지
                if (widget.kakaoConfigError != null)
                  Positioned(
                    left: 23,
                    top: 660,
                    child: Container(
                      width: 357,
                      alignment: Alignment.center,
                      child: Text(
                        widget.kakaoConfigError!,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

// 8. Kakao Login Button (Top: 698, Left: 23)
                Positioned(
                  left: 23,
                  top: 730,
                  child: GestureDetector(
                    onTap: () => _handleKakaoLogin(context),
                    child: Image.asset(
                      'lib/assets/icons/welcome_sc/kakao_login_medium_wide.png', // 이전에 쓰던 이미지 경로
                      width: 357,
                      height: 53,
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

// ============================================================
// [New] 통통 튀는 애니메이션 위젯 (여기에 추가됨)
// ============================================================
class BouncingAnimation extends StatefulWidget {
  final Widget child;
  final int delay; // 시작 딜레이 (ms)
  final double bounceDistance; // 얼마나 튀어 오를지 (0.0 ~ 1.0 비율)
  final Duration duration; // 한 번 튀어 오르는 시간

  const BouncingAnimation({
    super.key,
    required this.child,
    this.delay = 0,
    this.bounceDistance = 0.08, // 기본값: 살짝 위로 튀어 오름 (높이의 8%)
    this.duration = const Duration(milliseconds: 1200), // 기본값: 1.2초
  });

  @override
  State<BouncingAnimation> createState() => _BouncingAnimationState();
}

class _BouncingAnimationState extends State<BouncingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, -widget.bounceDistance), // 위로 튀어 오르는 거리
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // 지정된 딜레이 후에 애니메이션 시작
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true); // 무한 반복 (올라갔다 내려오기)
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}
