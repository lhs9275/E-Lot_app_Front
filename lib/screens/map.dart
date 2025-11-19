// lib/screens/map.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/h2_station.dart';
import '../services/h2_station_api_service.dart';
import 'favorite.dart'; // ⭐ 즐겨찾기 페이지 연결

/// ✅ 이 파일 단독 실행용 엔트리 포인트
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
  if (clientId == null || clientId.isEmpty) {
    debugPrint('❌ NAVER_MAP_CLIENT_ID가 .env에 없습니다.');
  }

  // 새 방식 init (권장)
  await FlutterNaverMap().init(
    clientId: clientId ?? '',
    onAuthFailed: (ex) {
      debugPrint('NaverMap auth failed: $ex');
    },
  );

  // H2 API 인스턴스 초기화 (이미 전역으로 있다면 이 부분은 네 프로젝트 구조에 맞게)
  final h2BaseUrl = dotenv.env['H2_API_BASE_URL'];
  if (h2BaseUrl == null || h2BaseUrl.isEmpty) {
    debugPrint('❌ H2_API_BASE_URL 이 .env에 없습니다.');
  } else {
    h2StationApi = H2StationApiService(baseUrl: h2BaseUrl);
  }

  runApp(const _MapApp());
}

/// 🔹 MapScreen만 보여주는 최소 앱 래퍼
class _MapApp extends StatelessWidget {
  const _MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _controller;
  List<H2Station> _stations = [];
  bool _isLoadingStations = true;
  String? _stationError;

  // 시작 위치 (예: 서울시청)
  final NLatLng _initialTarget = const NLatLng(37.5666, 126.9790);
  late final NCameraPosition _initialCamera =
  NCameraPosition(target: _initialTarget, zoom: 8.5);

  int _selectedIndex = 0;

  /// ⭐ 백엔드 주소 (clos21)
  static const String _backendBaseUrl = 'https://clos21.kr';

  /// ⭐ 즐겨찾기 상태 (stationId 기준)
  final Set<String> _favoriteStationIds = {};

  bool _isFavoriteStation(H2Station station) =>
      _favoriteStationIds.contains(station.stationId);

  Future<void> _toggleFavoriteStation(H2Station station) async {
    final stationId = station.stationId;
    final isFav = _favoriteStationIds.contains(stationId);

    final url =
    Uri.parse('$_backendBaseUrl/api/stations/$stationId/favorite');
    debugPrint('➡️ 즐겨찾기 API 호출: $url (isFav=$isFav)');

    // TODO: 실제 로그인 후 발급받은 토큰으로 교체해줘
    const accessToken = 'YOUR_ACCESS_TOKEN_HERE';

    try {
      http.Response res;

      if (!isFav) {
        // ⭐ 즐겨찾기 추가 (POST)
        res = await http.post(
          url,
          headers: {
            if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
          },
        );

        debugPrint(
            '⬅️ POST 결과: ${res.statusCode} ${res.body.isEmpty ? '' : res.body}');

        if (res.statusCode == 201 ||
            res.statusCode == 200 ||
            res.statusCode == 204) {
          setState(() {
            _favoriteStationIds.add(stationId);
          });
          debugPrint('✅ 즐겨찾기 추가 성공: $stationId');
        } else {
          debugPrint('❌ 즐겨찾기 추가 실패: ${res.statusCode} ${res.body}');
        }
      } else {
        // ⭐ 즐겨찾기 해제 (DELETE)
        res = await http.delete(
          url,
          headers: {
            if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
          },
        );

        debugPrint(
            '⬅️ DELETE 결과: ${res.statusCode} ${res.body.isEmpty ? '' : res.body}');

        if (res.statusCode == 204 || res.statusCode == 200) {
          setState(() {
            _favoriteStationIds.remove(stationId);
          });
          debugPrint('✅ 즐겨찾기 해제 성공: $stationId');
        } else {
          debugPrint('❌ 즐겨찾기 해제 실패: ${res.statusCode} ${res.body}');
        }
      }
    } catch (e) {
      debugPrint('❌ 즐겨찾기 토글 중 오류: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: _initialCamera,
                locationButtonEnable: true,
              ),

              /// ⭐ 클러스터 옵션 추가 부분
              clusterOptions: NaverMapClusteringOptions(
                // 어느 정도 화면 픽셀 거리 안에 모여있으면 하나로 뭉칠지 설정
                mergeStrategy: const NClusterMergeStrategy(
                  willMergedScreenDistance: {
                    NaverMapClusteringOptions.defaultClusteringZoomRange: 35,
                  },
                ),
                // 실제 “N개”라고 표시되는 클러스터 마커 꾸미는 콜백
                clusterMarkerBuilder: (info, clusterMarker) {
                  // info.size == 이 클러스터 안에 포함된 마커 개수
                  clusterMarker.setIsFlat(true);
                  clusterMarker.setCaption(
                    NOverlayCaption(
                      text: info.size.toString(),
                      color: Colors.white,
                      haloColor: Colors.blueAccent,
                    ),
                  );
                },
              ),
              onMapReady: _handleMapReady,
            ),

            if (_isLoadingStations) _buildLoadingBanner(),
            if (_stationError != null) _buildErrorBanner(),
            if (!_isLoadingStations &&
                _stationError == null &&
                _mappableStationCount > 0)
              _buildStationsBadge(),
            if (!_isLoadingStations &&
                _stationError == null &&
                _mappableStationCount == 0)
              _buildInfoBanner(
                icon: Icons.info_outline,
                message: '표시할 충전소 위치 데이터가 없습니다.',
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoadingStations ? null : _onCenterButtonPressed,
        child: _isLoadingStations
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        )
            : const Icon(Icons.refresh),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.star_border, // ⭐ 목록 → 즐겨찾기
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

  Widget _buildLoadingBanner() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  '충전소 위치 불러오는 중...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _stationError ?? '알 수 없는 오류',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _loadStations,
                  child: const Text('재시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner({required IconData icon, required String message}) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationsBadge() {
    return Positioned(
      top: 16,
      left: 16,
      child: Chip(
        avatar: const Icon(Icons.ev_station, size: 16, color: Colors.white),
        label: Text('표시 중: $_mappableStationCount개 충전소'),
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  void _handleMapReady(NaverMapController controller) {
    _controller = controller;
    unawaited(_renderStationMarkers());
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoadingStations = true;
      _stationError = null;
    });

    try {
      final stations = await h2StationApi.fetchStations();
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _isLoadingStations = false;
      });
      unawaited(_renderStationMarkers());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingStations = false;
        _stationError = '충전소 데이터를 불러오지 못했습니다.';
      });
      debugPrint('H2 station fetch failed: $error');
    }
  }

  Future<void> _renderStationMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.clearOverlays(type: NOverlayType.marker);
    } catch (_) {
      // ignore controller clear errors
    }

    if (_mappableStationCount == 0) return;

    // ⭐ 여기서 NMarker → NClusterableMarker 로 변경
    final overlays = _stationsWithCoordinates.map((station) {
      final lat = station.latitude!;
      final lng = station.longitude!;
      final markerId = 'h2_marker_${station.stationName}_$lat$lng';

      final marker = NClusterableMarker(
        id: markerId,
        position: NLatLng(lat, lng),
        caption: NOverlayCaption(
          text: station.stationName,
          textSize: 12,
          color: Colors.black,
          haloColor: Colors.white,
        ),
        iconTintColor: _statusColor(station.statusName),
      );

      marker.setOnTapListener((overlay) {
        _showStationBottomSheet(station);
      });
      return marker;
    }).toSet();

    if (overlays.isEmpty) return;
    await controller.addOverlayAll(overlays);
  }

  Iterable<H2Station> get _stationsWithCoordinates => _stations.where(
        (station) => station.latitude != null && station.longitude != null,
  );

  int get _mappableStationCount => _stationsWithCoordinates.length;

  Color _statusColor(String statusName) {
    final normalized = statusName.trim();
    switch (normalized) {
      case '영업중':
        return Colors.green;
      case '점검중':
      case 'T/T교체':
        return Colors.orange;
      case '영업중지':
        return Colors.redAccent;
      default:
        return Colors.indigo;
    }
  }

  void _showStationBottomSheet(H2Station station) {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        // 바텀시트 안 전용 setState를 위한 StatefulBuilder
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isFav = _isFavoriteStation(station);

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          station.stationName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () async {
                          await _toggleFavoriteStation(station);
                          setSheetState(() {}); // 별 상태 다시 그림
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStationField('운영 상태', station.statusName),
                  _buildStationField(
                    '대기 차량',
                    '${station.waitingCount ?? 0}대',
                  ),
                  _buildStationField(
                    '최대 충전 가능',
                    station.maxChargeCount != null
                        ? '${station.maxChargeCount}대'
                        : '정보 없음',
                  ),
                  _buildStationField(
                    '최종 갱신',
                    station.lastModifiedAt ?? '정보 없음',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStationField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _onTapItem(int idx) {
    setState(() => _selectedIndex = idx);

    switch (idx) {
      case 0:
        _controller?.updateCamera(
          NCameraUpdate.fromCameraPosition(
            NCameraPosition(target: _initialTarget, zoom: 10),
          ),
        );
        break;
      case 1:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('근처 보기 준비 중입니다.')),
        );
        break;
      case 2:
      // ⭐ 즐겨찾기 페이지로 이동 (목록은 나중에 백엔드 GET으로 구성)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FavoritesPage(),
          ),
        );
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 정보 보기 준비 중입니다.')),
        );
        break;
    }
  }

  void _onCenterButtonPressed() {
    _loadStations();
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
