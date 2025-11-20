// lib/widgets/main_bottom_nav_bar.dart
import 'package:flutter/material.dart';

/// 하단 네비게이션에서 탭을 눌렀을 때 호출되는 콜백 타입
typedef BottomNavTapCallback = void Function(int index);

/// ✅ 메인 하단 네비게이션 바
class MainBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final BottomNavTapCallback onTapItem;

  const MainBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_filled,
            label: '홈',
            selected: selectedIndex == 0,
            onTap: () => onTapItem(0),
          ),
          _NavItem(
            icon: Icons.place_outlined,
            label: '근처',
            selected: selectedIndex == 1,
            onTap: () => onTapItem(1),
          ),
          const SizedBox(width: 48),
          _NavItem(
            icon: Icons.star_border,
            label: '즐겨찾기',
            selected: selectedIndex == 2,
            onTap: () => onTapItem(2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: '내 정보',
            selected: selectedIndex == 3,
            onTap: () => onTapItem(3),
          ),
        ],
      ),
    );
  }
}

/// 🔹 하단 네비 아이템(아이콘+텍스트)
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2563EB) : Colors.grey[600];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
