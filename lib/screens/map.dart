import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'bookmark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterNaverMap().init(
    clientId: 'hoivm494r9', // 네이버 콘솔 Client ID
    onAuthFailed: (e) => debugPrint('NaverMap auth failed: $e'),
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MapScreen(),
  ));
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _controller;

  // 시작 위치 (예: 서울시청)
  final NLatLng _initialTarget = const NLatLng(37.5666, 126.9790);
  late final NCameraPosition _initialCamera =
  NCameraPosition(target: _initialTarget, zoom: 14);

  int _selectedIndex = 0; // 하단 탭 선택 인덱스

  // FAB이 안 움직이도록 'floating' 스낵바 사용
  void _showStatus(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        // 살짝 아래 (기기에 따라 더 조절 가능)
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 지도 본문
      body: SafeArea(
        child: NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: _initialCamera,
          ),
          onMapReady: (c) {
            _controller = c;
            final marker = NMarker(
              id: 'start_marker',
              position: _initialTarget,
              caption: const NOverlayCaption(text: '서울시청'),
            );
            c.addOverlay(marker);
          },
        ),
      ),

      // 가운데 동그란 버튼(예: 챗봇/메뉴 등)
      floatingActionButton: FloatingActionButton(
        onPressed: _onCenterButtonPressed,
        child: Image.asset(
          'lib/assets/icons/mascot_character/sparky.png',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 하단 버튼바 (FAB 홈 파인 모양)
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_filled,
              label: '홈',
              selected: _selectedIndex == 0,
              onTap: () => _onTapItem(0),
            ),
            _NavItem(
              icon: Icons.place_outlined,
              label: '근처',
              selected: _selectedIndex == 1,
              onTap: () => _onTapItem(1),
            ),

            // FAB 자리 비우기
            const SizedBox(width: 48),

            // ✅ 즐겨찾기(별 아이콘)
            _NavItem(
              icon: _selectedIndex == 2 ? Icons.star : Icons.star_outline,
              label: '즐겨찾기',
              selected: _selectedIndex == 2,
              onTap: () => _onTapItem(2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: '내 정보',
              selected: _selectedIndex == 3,
              onTap: () => _onTapItem(3),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapItem(int idx) {
    setState(() => _selectedIndex = idx);

    // 탭별 동작
    switch (idx) {
      case 0: // 홈
        _controller?.updateCamera(
          NCameraUpdate.fromCameraPosition(
            NCameraPosition(target: _initialTarget, zoom: 14),
          ),
        );
        _showStatus('홈으로 이동');
        break;

      case 1: // 근처
        _showStatus('근처 보기 준비 중');
        break;

      case 2: // ✅ 즐겨찾기: 화면 전환(Push)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FavoritesPage()),
        );
        break;

      case 3: // 내 정보
        _showStatus('내 정보 보기 준비 중');
        break;
    }
  }

  void _onCenterButtonPressed() {
    // 가운데 버튼 동작 (예: 현재 위치로 이동 등)
    _showStatus('가운데 버튼 눌림!');
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}

/// 하단 네비 아이템(아이콘+텍스트)
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
