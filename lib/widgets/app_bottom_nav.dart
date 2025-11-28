import 'package:flutter/material.dart';

import '../screens/favorite.dart';
import '../screens/map.dart';
import '../screens/mypage.dart';

/// 모든 페이지에서 재사용하는 하단 네비게이션 바.
/// - current: 현재 선택된 탭
/// - onItemSelected: 탭 변경 알림(필요 없으면 null)
/// - enableRouting: true면 기본 이동(pushReplacement) 수행
/// - builders: 탭별 이동 대상을 덮어쓸 때 사용
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.current,
    this.onItemSelected,
    this.enableRouting = true,
    this.builders,
    this.backgroundColor,
    this.indicatorColor,
    this.height,
    this.showLabels = true,
  });

  final AppNavItem current;
  final ValueChanged<AppNavItem>? onItemSelected;
  final bool enableRouting;
  final Map<AppNavItem, WidgetBuilder>? builders;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final double? height;
  final bool showLabels;

  static final List<_AppDestination> _defaultDestinations = [
    _AppDestination(
      item: AppNavItem.map,
      label: '지도',
      icon: Icons.map_rounded,
      builder: (_) => const MapScreen(),
    ),
    _AppDestination(
      item: AppNavItem.nearby,
      label: '주변',
      icon: Icons.near_me_rounded,
      builder: null, // 추후 화면 연결 시 builders로 덮어쓰기
    ),
    _AppDestination(
      item: AppNavItem.favorites,
      label: '즐겨찾기',
      icon: Icons.star_rounded,
      builder: (_) => const FavoritesPage(),
    ),
    _AppDestination(
      item: AppNavItem.myPage,
      label: '마이페이지',
      icon: Icons.person_rounded,
      builder: (_) => const MyPageScreen(),
    ),
  ];

  void _handleTap(BuildContext context, int tappedIndex) {
    final destination = _defaultDestinations[tappedIndex];
    final targetBuilder = builders?[destination.item] ?? destination.builder;

    onItemSelected?.call(destination.item);

    if (!enableRouting || destination.item == current) return;

    if (targetBuilder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('준비 중입니다.')),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: targetBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _defaultDestinations
        .indexWhere((d) => d.item == current)
        .clamp(0, _defaultDestinations.length - 1);

    return NavigationBar(
      height: height,
      selectedIndex: selectedIndex,
      onDestinationSelected: (idx) => _handleTap(context, idx),
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.surface,
      indicatorColor:
          indicatorColor ?? Theme.of(context).colorScheme.primaryContainer,
      labelBehavior: showLabels
          ? NavigationDestinationLabelBehavior.alwaysShow
          : NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: _defaultDestinations
          .map(
            (d) => NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon ?? d.icon),
              label: d.label,
            ),
          )
          .toList(),
    );
  }
}

enum AppNavItem { map, nearby, favorites, myPage }

class _AppDestination {
  const _AppDestination({
    required this.item,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.builder,
  });

  final AppNavItem item;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final WidgetBuilder? builder;
}
