import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

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
        child: const Icon(Icons.android), // 스샷의 로봇 느낌
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 하단 버튼바 (FAB이 들어갈 홈이 파이는 모양)
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
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

            _NavItem(
              icon: Icons.list_alt,
              label: '목록',
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

    // 필요하면 탭별 동작 연결
    switch (idx) {
      case 0: // 홈
        _controller?.updateCamera(
          NCameraUpdate.fromCameraPosition(
            NCameraPosition(target: _initialTarget, zoom: 14),
          ),
        );
        break;
      case 1: // 근처
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('근처 보기 준비 중')),
        );
        break;
      case 2: // 목록
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목록 보기 준비 중')),
        );
        break;
      case 3: // 내 정보
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 정보 보기 준비 중')),
        );
        break;
    }
  }

  void _onCenterButtonPressed() {
    // 가운데 버튼 동작 (예: 현재 위치로 이동 등)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('가운데 버튼 눌림!')),
    );
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
