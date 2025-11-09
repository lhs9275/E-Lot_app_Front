import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(),
                        ),
                      );
                    },
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