import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/route_ranking_models.dart';
import '../../services/route_ranking_api_service.dart';
import '../bottom_navbar.dart';
import 'destination_picker.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late final RouteRankingApiService _api;

  double? _startLat;
  double? _startLng;
  double? _endLat;
  double? _endLng;
  String _startLabel = '현재 위치';
  String? _endLabel;

  double _radiusKm = 5;
  bool _includeEv = true;
  bool _includeH2 = true;
  bool _includeParking = true;
  int _limit = 10;

  bool _loading = false;
  String? _error;
  RouteInfo? _routeInfo;
  List<RankedStation> _results = const <RankedStation>[];

  static const String _defaultPreset = 'BALANCED';

  // --- 🎨 디자인 컬러 팔레트 (여기가 핵심!) ---
  final Color _bgColor = const Color(0xFFF9FBFD); // 깨끗한 배경
  final Color _cardColor = Colors.white;

  // 포인트 컬러: 보라색 (기존 색 유지하되, 강약 조절용 컬러 추가)
  final Color _primaryColor = const Color(0xFF5F33DF);
  final Color _primaryLight = const Color(0xFFF0EBFF); // 아주 연한 보라 (배경용)
  final Color _primaryGradientEnd = const Color(0xFF7A5AF8); // 그라데이션 끝색

  final Color _textColor = const Color(0xFF1A1A1A); // 진한 검정 (가독성)
  final Color _subTextColor = const Color(0xFF8E929C); // 세련된 회색

  @override
  void initState() {
    super.initState();
    final base = dotenv.env['EV_API_BASE_URL']?.trim();
    final baseUrl = (base != null && base.isNotEmpty) ? base : 'https://clos21.kr';
    _api = RouteRankingApiService(baseUrl: baseUrl);
    _initLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- 기능 로직 (절대 건드리지 않음) ---
  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('위치 서비스를 켜주세요.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('위치 권한이 필요합니다.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _startLat = pos.latitude;
        _startLng = pos.longitude;
        _startLabel = '현재 위치 설정됨';
      });
    } catch (e) {
      _showSnack('현재 위치를 불러오지 못했습니다.');
    }
  }

  Future<void> _pickDestination() async {
    final start = _startLat != null && _startLng != null
        ? NLatLng(_startLat!, _startLng!)
        : const NLatLng(37.5665, 126.9780);

    final picked = await Navigator.of(context).push<DestinationPickResult>(
      MaterialPageRoute(
        builder: (_) => DestinationPickerScreen(initialTarget: start),
      ),
    );

    if (picked == null) return;
    setState(() {
      _endLat = picked.position.latitude;
      _endLng = picked.position.longitude;
      _endLabel = picked.name ?? '선택한 위치';
    });
  }

  Future<void> _fetchRanking() async {
    if (_startLat == null || _startLng == null) {
      _showSnack('현재 위치를 먼저 가져와주세요.');
      return;
    }
    if (_endLat == null || _endLng == null) {
      _showSnack('목적지를 지도에서 선택해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.fetchRankings(
        startLat: _startLat!,
        startLng: _startLng!,
        endLat: _endLat!,
        endLng: _endLng!,
        radiusKm: _radiusKm,
        includeEv: _includeEv,
        includeH2: _includeH2,
        includeParking: _includeParking,
        preset: _defaultPreset,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _routeInfo = res.route;
        _results = res.rankedStations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '추천 랭킹을 불러오지 못했습니다.';
        _loading = false;
      });
      _showSnack(e.toString());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // --- 화면 UI (구조는 유지하되 디자인만 맛깔나게 변경) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
            '즐겨찾기',
            style: TextStyle(
              fontWeight: FontWeight.w800, // 폰트 두께 업
              color: _textColor,
              fontSize: 24,
              letterSpacing: -0.5, // 자간 살짝 좁게 (트렌디함)
            )
        ),
        backgroundColor: _bgColor,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 있으면 제거 (필요시 true)
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          physics: const BouncingScrollPhysics(), // 아이폰 스타일 탄성 스크롤
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildForm(), // 입력 폼
              const SizedBox(height: 24),
              _buildRouteInfo(), // 경로 정보
              const SizedBox(height: 12),

              // 상태에 따른 UI
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: _primaryColor),
                  ),
                )
              else if (_error != null)
                Center(child: Text(_error!, style: TextStyle(color: _subTextColor)))
              else if (_results.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60.0),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            '조건을 설정하고\n최적의 경로를 추천받아보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _subTextColor, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildResultList(), // 결과 리스트

              const SizedBox(height: 100), // 하단 여백
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(32), // 더 둥글게 (30 -> 32)
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F33DF).withOpacity(0.08), // 그림자 색상을 보라색 틴트로 살짝
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Text(
                  '경로 기반 추천',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _textColor
                  ),
                ),
                const Spacer(),
                Icon(Icons.auto_awesome, color: _primaryColor, size: 20), // 포인트 아이콘
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '출발/도착지를 설정하여 최적의 경로를 찾으세요.',
              style: TextStyle(color: _subTextColor, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // 위치 입력부 (Stepper 느낌)
            _buildLocationRow(),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F8)),
            ),

            // 옵션 (반경 & 개수)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '검색 반경 ${_radiusKm.toStringAsFixed(1)}km',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _textColor
                  ),
                ),
                // 드롭다운을 깔끔한 텍스트 버튼처럼
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _limit,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _subTextColor, size: 18),
                      isDense: true,
                      style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
                      items: const [5, 10, 15, 20]
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v개')))
                          .toList(),
                      onChanged: (v) => setState(() => _limit = v ?? 10),
                    ),
                  ),
                ),
              ],
            ),

            // 슬라이더 (커스텀 디자인)
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _primaryColor,
                inactiveTrackColor: _primaryLight, // 비활성 트랙을 아주 연하게
                thumbColor: Colors.white,
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
                overlayColor: _primaryColor.withOpacity(0.1),
              ),
              child: Slider(
                value: _radiusKm,
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => setState(() => _radiusKm = v),
              ),
            ),

            const SizedBox(height: 16),

            // 필터 칩 (Soft Style)
            Row(
              children: [
                Expanded(child: _buildSoftChip('⚡ 전기차', _includeEv, (v) => setState(() => _includeEv = v))),
                const SizedBox(width: 8),
                Expanded(child: _buildSoftChip('💧 수소차', _includeH2, (v) => setState(() => _includeH2 = v))),
                const SizedBox(width: 8),
                Expanded(child: _buildSoftChip('🅿️ 주차장', _includeParking, (v) => setState(() => _includeParking = v))),
              ],
            ),

            const SizedBox(height: 24),

            // 메인 버튼 (그라데이션 & 쉐도우)
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryGradientEnd], // 보라색 그라데이션
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _loading ? null : _fetchRanking,
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('최적 경로 추천받기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 칩 디자인 (촌스러운 보라색 박스 X -> 세련된 파스텔 톤 O)
  Widget _buildSoftChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primaryLight : Colors.white, // 선택되면 연보라, 아니면 흰색
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _primaryColor : const Color(0xFFE2E4E9), // 테두리
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _primaryColor : _subTextColor, // 글자색
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // 위치 선택 Row (디자인 개선)
  Widget _buildLocationRow() {
    return Column(
      children: [
        _buildLocationItem(
            icon: Icons.my_location_rounded,
            iconColor: _primaryColor,
            label: '출발지',
            value: _startLat == null ? '위치 확인 중...' : _startLabel,
            onTap: _initLocation,
            isHighlight: true
        ),

        // 점선 연결 느낌의 데코레이션
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 16,
              width: 2,
              color: const Color(0xFFF2F4F8),
            ),
          ),
        ),

        _buildLocationItem(
          icon: Icons.flag_rounded,
          iconColor: const Color(0xFFFF4B4B), // 도착지는 붉은 계열 포인트
          label: '도착지',
          value: _endLabel ?? '어디로 갈까요?',
          onTap: _pickDestination,
          isHighlight: _endLabel != null,
          isEmpty: _endLabel == null,
        ),
      ],
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isHighlight = false,
    bool isEmpty = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // 아이콘 박스
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: _subTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isEmpty ? _subTextColor.withOpacity(0.5) : _textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _subTextColor.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  // 경로 정보 요약 (카드 스타일)
  Widget _buildRouteInfo() {
    final route = _routeInfo;
    if (route == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround, // 균등 배치
        children: [
          _buildInfoItem(Icons.route_rounded, '총 거리', '${route.distanceKm?.toStringAsFixed(1) ?? '-'} km'),
          Container(height: 30, width: 1, color: _primaryColor.withOpacity(0.1)), // 구분선
          _buildInfoItem(Icons.timer_rounded, '예상 시간', '${route.estimatedDurationMin?.toStringAsFixed(0) ?? '-'} 분'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: _primaryColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: _primaryColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // 결과 리스트 (기존 구조 유지, 디자인 디테일 업)
  Widget _buildResultList() {
    return ListView.builder(
      itemCount: _results.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = _results[index];
        final isTop = index == 0;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            // 1등은 테두리로 살짝 강조
            border: isTop ? Border.all(color: const Color(0xFFFFD700), width: 1.5) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 순위 뱃지
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isTop ? const Color(0xFFFFD700) : const Color(0xFFF2F4F8),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${item.rank}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isTop ? Colors.white : _subTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.station.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _textColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.station.type} · 이탈 ${item.station.distanceFromRouteKm?.toStringAsFixed(1) ?? '-'} km',
                      style: TextStyle(color: _subTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    // 태그들
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildMiniTag('⭐ 점수 ${item.score.toStringAsFixed(1)}', const Color(0xFFFFF9DB), const Color(0xFFE6B800)),
                        if (item.station.detourMinutes != null)
                          _buildMiniTag('⏱️ +${item.station.detourMinutes}분', const Color(0xFFFFECEC), const Color(0xFFFF6B6B)),
                      ],
                    )
                  ],
                ),
              ),

              // 즐겨찾기 별 (보라색 포인트)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.star_rounded, color: _primaryColor, size: 22),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniTag(String text, Color bg, Color txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: txt, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
