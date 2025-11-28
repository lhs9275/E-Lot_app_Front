// lib/screens/bottom_navbar.dart
import 'package:flutter/material.dart';

// 🔁 각 탭이 열어줄 화면들 import
import 'map.dart';
import 'favorite.dart';
import 'mypage.dart';

class MainBottomNavBar extends StatelessWidget {
  /// 현재 선택된 탭 index (0: 지도, 1: 근처, 2: 즐겨찾기, 3: 내 정보)
  final int currentIndex;

  const MainBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  // ✨ 디자인용 색상 정의 (이미지 속 보라색)
  final Color _purple = const Color(0xFF7253FF);
  // final Color _lightPurple = const Color(0xFFE9E3FF); // 배경색이 필요 없으면 주석 처리
  final Color _iconGrey = const Color(0xFFB5B5C3); // 선택 안 된 아이콘 색

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('충전소 찾기 기능은 준비 중입니다.')),
      );
      return;
    }

    Widget target;
    switch (index) {
      case 0: // 지도 (차 아이콘)
        target = const MapScreen();
        break;
      case 2: // 즐겨찾기 (리스트 아이콘)
        target = const FavoritesPage();
        break;
      case 3: // 내 정보 (사람 아이콘)
        target = const MyPageScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        // 👆 튀어나올 공간 확보를 위해 전체 컨테이너 높이를 넉넉히 줌 (85~90)
        height: 90,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Stack(
          alignment: Alignment.bottomCenter, // 하단 중앙 정렬
          clipBehavior: Clip.none, // 🚀 중요: 캐릭터가 영역 밖으로 튀어나가도 잘리지 않게 함
          children: [
            // 1️⃣ 배경이 되는 하얀색 바 (아이콘들)
            Container(
              height: 72, // 바 높이
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(0.08),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 좌측 아이콘
                  _buildNavItem(context, index: 0, icon: Icons.directions_car_outlined, selectedIcon: Icons.directions_car_rounded),
                  _buildNavItem(context, index: 1, icon: Icons.bolt_outlined, selectedIcon: Icons.bolt_rounded),

                  // ✨ 중앙 공백 (캐릭터가 들어갈 자리를 비워둠)
                  const SizedBox(width: 70),

                  // 우측 아이콘
                  _buildNavItem(context, index: 2, icon: Icons.assignment_outlined, selectedIcon: Icons.assignment_rounded),
                  _buildNavItem(context, index: 3, icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded),
                ],
              ),
            ),

            // 2️⃣ 튀어나온 캐릭터 (Positioned로 위치 잡기)
            Positioned(
              bottom: -10, // 👆 숫자를 키울수록 더 위로 올라갑니다
              child: _buildCenterImageItem(context),
            ),
          ],
        ),
      ),
    );
  }

  // 아이콘 빌더
  Widget _buildNavItem(BuildContext context, {
    required int index,
    required IconData icon,        // 기본 아이콘 (테두리)
    required IconData selectedIcon // 선택됐을 때 아이콘 (채워짐)
  }) {
    final bool isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => _handleTap(context, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        color: Colors.transparent, // 터치 영역 확보
        child: Icon(
          isSelected ? selectedIcon : icon, // 선택되면 꽉 찬 아이콘, 아니면 테두리
          size: 28, // 아이콘 크기 조금 키움
          color: isSelected ? _purple : _iconGrey,
        ),
      ),
    );
  }

  // 가운데 캐릭터 이미지 빌더
  Widget _buildCenterImageItem(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('안녕하세요! 저는 E-Lot 마스코트입니다! 👋')),
        );
      },
      child: Container(
        width: 100, // 🚀 크기를 100으로 대폭 키움
        height: 100,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'lib/assets/icons/mascot_character/sparky.png',
          fit: BoxFit.contain, // 박스 크기(100x100)에 맞춰 비율 유지하며 꽉 채움
        ),
      ),
    );
  }
}