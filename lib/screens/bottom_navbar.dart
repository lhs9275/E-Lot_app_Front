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

  void _handleTap(BuildContext context, int index) {
    // 같은 탭 다시 누르면 아무 것도 안 함
    if (index == currentIndex) return;

    // 1: 근처 보기 탭은 아직 화면 없음 → 그냥 스낵바만
    if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근처 보기 기능은 준비 중입니다.')),
      );
      return;
    }

    Widget target;

    switch (index) {
      case 0: // 지도
        target = const MapScreen();
        break;
      case 2: // 즐겨찾기
        target = const FavoritesPage();
        break;
      case 3: // 내 정보
        target = const MyPageScreen();
        break;
      default:
        return;
    }

    // 🔁 탭 이동: 스택을 쌓지 않고 현재 페이지를 대체
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (idx) => _handleTap(context, idx),
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.map_rounded),
          label: '지도',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.near_me_rounded),
          label: '근처',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.star_rounded),
          label: '즐겨찾기',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: '내 정보',
        ),
      ],
    );
  }
}
