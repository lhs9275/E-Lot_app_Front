// lib/screens/map/map_screen.dart
import 'dart:async';
import 'dart:convert'; // ⭐ 즐겨찾기 동기화용 JSON 파싱
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'cluster_options.dart';
import 'map_controller.dart';
import 'marker_builders.dart';
import 'widgets/filter_bar.dart';
import 'widgets/search_bar.dart';
import 'widgets/status_banners.dart';

import '../../models/ev_station.dart';
import '../../models/h2_station.dart';
import '../../models/parking_lot.dart';
import '../../services/ev_station_api_service.dart';
import '../../services/h2_station_api_service.dart';
import '../etc/review_list.dart';
import '../../services/parking_lot_api_service.dart';
import '../bottom_navbar.dart'; // ✅ 공통 하단 네비게이션 바
import '../etc/review.dart'; // ⭐ 리뷰 작성 페이지
import 'package:psp2_fn/auth/token_storage.dart'; // 🔑 JWT 저장소

/// 🔍 검색용 후보 모델
class _SearchCandidate {
  final String name;
  final bool isH2;
  final H2Station? h2;
  final EVStation? ev;
  final double lat;
  final double lng;

  const _SearchCandidate({
    required this.name,
    required this.isH2,
    this.h2,
    this.ev,
    required this.lat,
    required this.lng,
  });
}

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

  final evBaseUrl = dotenv.env['EV_API_BASE_URL'];
  if (evBaseUrl == null || evBaseUrl.isEmpty) {
    debugPrint('❌ EV_API_BASE_URL 이 .env에 없습니다.');
  } else {
    evStationApi = EVStationApiService(baseUrl: evBaseUrl);
  }

  final parkingBaseUrl =
      dotenv.env['PARKING_API_BASE_URL'] ?? evBaseUrl ?? h2BaseUrl;
  if (parkingBaseUrl == null || parkingBaseUrl.isEmpty) {
    debugPrint('❌ PARKING_API_BASE_URL 이 .env에 없습니다.');
  } else {
    parkingLotApi = ParkingLotApiService(baseUrl: parkingBaseUrl);
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

/// 네이버 지도를 렌더링하면서 충전소 데이터를 보여주는 메인 스크린.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// 지도 상호작용, 충전소 호출 및 즐겨찾기를 모두 관리하는 상태 객체.
class _MapScreenState extends State<MapScreen> {
  // --- 상태 필드들 ---
  final MapController _mapController = MapController(
    h2Api: h2StationApi,
    evApi: evStationApi,
    parkingApi: parkingLotApi,
  );
  NaverMapController? _controller;
  NOverlayImage? _clusterIcon;

  // 검색창 컨트롤러
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 🔍 자동완성 후보 목록
  List<_SearchCandidate> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchFocused = false;
  String? _searchError;

  bool _isManualRefreshing = false;
  bool _isMapLoaded = false;

  // 시작 위치 (예: 서울시청)
  final NLatLng _initialTarget = const NLatLng(37.5666, 126.9790);
  late final NCameraPosition _initialCamera = NCameraPosition(
    target: _initialTarget,
    zoom: 8.5,
  );

  /// ⭐ 백엔드 주소 (clos21)
  static const String _backendBaseUrl = 'https://clos21.kr';

  /// ⭐ 리뷰에서 사용할 기본 이미지 (충전소 개별 사진이 아직 없으므로 공통)
  static const String _defaultStationImageUrl =
      'https://images.unsplash.com/photo-1483721310020-03333e577078?q=80&w=800&auto=format&fit=crop';

  /// ⭐ 즐겨찾기 상태 (stationId 기준)
  final Set<String> _favoriteStationIds = {};

  /// 💡 지도 마커 색상 (유형 구분)
  static const Color _h2MarkerBaseColor = Color(0xFF2563EB); // 파란색 톤
  static const Color _evMarkerBaseColor = Color(0xFF10B981); // 초록색 톤
  static const Color _parkingMarkerBaseColor = Color(0xFFF59E0B); // 주차장 주황

  /// 클러스터 옵션 (기본값)
  NaverMapClusteringOptions get _clusterOptions => defaultClusterOptions;

  String? get _stationError => _mapController.stationError;
  List<DynamicIslandAction> _dynamicIslandActions = [];
  bool _isBuildingSuggestions = false;

  Iterable<H2Station> get _h2StationsWithCoordinates =>
      _mapController.h2StationsWithCoords;
  Iterable<EVStation> get _evStationsWithCoordinates =>
      _mapController.evStationsWithCoords;
  Iterable<ParkingLot> get _parkingLotsWithCoordinates =>
      _mapController.parkingLotsWithCoords;

  int get _totalMappableMarkerCount => _mapController.totalMappableCount;

  // --- 라이프사이클 ---
  @override
  void initState() {
    super.initState();
    _mapController.addListener(_onMapControllerChanged);
    _mapController.loadAllStations();
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
      if (_searchFocusNode.hasFocus) {
        unawaited(_refreshDynamicIslandSuggestions());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareClusterIcon());
  }

  @override
  void dispose() {
    _controller = null;
    _searchController.dispose(); // 검색창 컨트롤러 정리
    _searchFocusNode.dispose();
    _mapController.removeListener(_onMapControllerChanged);
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _prepareClusterIcon() async {
    try {
      final icon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _h2MarkerBaseColor,
            shape: BoxShape.circle,
          ),
        ),
        context: context,
      );
      if (!mounted) return;
      setState(() => _clusterIcon = icon);
    } catch (e) {
      debugPrint('Cluster icon build failed: $e');
    }
  }

  void _onMapControllerChanged() {
    // 데이터/필터 변경 시 UI와 마커를 갱신한다.
    if (_isMapLoaded && _controller != null) {
      unawaited(_renderStationMarkers());
    }
    if (_isSearchFocused) {
      unawaited(_refreshDynamicIslandSuggestions());
    }
    if (mounted) setState(() {});
  }

  // --- build & UI 구성 ---
  @override
  Widget build(BuildContext context) {
    // 하단 네비게이션 바(높이 90 + 마진 20)와 기기 하단 패딩만큼 지도 UI 여백을 줘서
    // 기본 제공 버튼(현재 위치 등)이 바 뒤로 숨지 않도록 한다.
    const double navBarHeight = 60;
    const double navBarBottomMargin = 10; // 바를 살짝 더 아래로 내려 여백을 줄임
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double mapBottomPadding =
        navBarHeight + navBarBottomMargin + bottomInset;
    final bool isLoading = _mapController.isLoading;

    return Scaffold(
      extendBody: true, // 바 뒤로 본문을 확장해서 지도가 바 아래까지 깔리도록 함
      body: SafeArea(
        top: true,
        bottom: false, // 하단 네비게이션 영역까지 지도가 깔리도록 bottom 패딩 제거
        child: Stack(
          children: [
            NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: _initialCamera,
                locationButtonEnable: true,
                contentPadding: EdgeInsets.only(bottom: mapBottomPadding),
              ),

              /// ⭐ 클러스터 옵션 (플러그인 기본값 사용 — iOS/Android 동일 동작)
              clusterOptions: _clusterOptions,
              onMapReady: _handleMapReady,
              onMapLoaded: _handleMapLoaded,
            ),

            /// 🔍 상단 검색창 + 자동완성 리스트
            Positioned(
              top: 45, // ⬅️ 살짝 아래로 내린 위치
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  FilterBar(
                    showH2: _mapController.showH2,
                    showEv: _mapController.showEv,
                    showParking: _mapController.showParking,
                    h2Color: _h2MarkerBaseColor,
                    evColor: _evMarkerBaseColor,
                    parkingColor: _parkingMarkerBaseColor,
                    onToggleH2: _mapController.toggleH2,
                    onToggleEv: _mapController.toggleEv,
                    onToggleParking: _mapController.toggleParking,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 4),
        child: FloatingActionButton(
          onPressed: _isManualRefreshing ? null : _refreshStations,
          child: _isManualRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.refresh),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      /// ✅ 하단 네비게이션 바 (지도 탭이므로 index = 0)
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
    );
  }

  /// 🔍 상단 검색창 UI + 유사 이름 리스트
  Widget _buildSearchBar() {
    return SearchBarSection(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onSubmitted: _onSearchSubmitted,
      onClear: () {
        setState(() {
          _searchController.clear();
          _searchResults = [];
        });
      },
      searchResults: _searchResults
          .map(
            (e) => SearchResultItem(
              name: e.name,
              subtitle: e.isH2 ? '[H2]' : '[EV]',
              lat: e.lat,
              lng: e.lng,
              h2: e.h2,
              ev: e.ev,
            ),
          )
          .toList(),
      onResultTap: (item) {
        if (item.h2 != null) {
          _showH2StationBottomSheet(item.h2 as H2Station);
        } else if (item.ev != null) {
          _showEvStationBottomSheet(item.ev as EVStation);
        }
      },
      onResultMarkerTap: (item) => _focusTo(item.lat, item.lng),
      searchError: _searchError,
      isSearching: _isSearching,
      showDynamicIsland: _isSearchFocused,
      actions: _dynamicIslandActions,
      onActionTap: _handleQuickAction,
    );
  }

  /// 🔍 타이핑할 때마다 유사 이름 후보 찾아서 리스트에 넣기
  void _onSearchChanged(String raw) {
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final lower = query.toLowerCase();
    final List<_SearchCandidate> results = [];

    // H2 쪽에서 이름에 query가 포함된 것
    for (final s in _h2StationsWithCoordinates) {
      final name = s.stationName;
      if (name.toLowerCase().contains(lower)) {
        results.add(
          _SearchCandidate(
            name: name,
            isH2: true,
            h2: s,
            ev: null,
            lat: s.latitude!,
            lng: s.longitude!,
          ),
        );
      }
    }

    // EV 쪽에서 이름에 query가 포함된 것
    for (final s in _evStationsWithCoordinates) {
      final name = s.stationName;
      if (name.toLowerCase().contains(lower)) {
        results.add(
          _SearchCandidate(
            name: name,
            isH2: false,
            h2: null,
            ev: s,
            lat: s.latitude!,
            lng: s.longitude!,
          ),
        );
      }
    }

    // 너무 길어지지 않게 상위 몇 개만 (예: 8개)
    if (results.length > 8) {
      results.removeRange(8, results.length);
    }

    setState(() {
      _searchResults = results;
    });
  }

  /// 🔍 자동완성 후보 하나를 탭했을 때 동작
  void _onTapSearchCandidate(_SearchCandidate item) {
    _searchController.text = item.name;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
    });

    _controller?.updateCamera(
      NCameraUpdate.fromCameraPosition(
        NCameraPosition(target: NLatLng(item.lat, item.lng), zoom: 14),
      ),
    );

    if (item.isH2 && item.h2 != null) {
      _showH2StationBottomSheet(item.h2!);
    } else if (!item.isH2 && item.ev != null) {
      _showEvStationBottomSheet(item.ev!);
    }
  }

  /// 검색 실행 로직: 엔터/돋보기 눌렀을 때
  void _onSearchSubmitted(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('충전소 이름을 입력해주세요.')));
      return;
    }

    // 자동완성 목록이 있으면 첫 번째 추천 바로 사용
    if (_searchResults.isNotEmpty) {
      _onTapSearchCandidate(_searchResults.first);
      return;
    }

    final lower = query.toLowerCase();

    // 1) H2에서 먼저 찾고
    H2Station? foundH2;
    for (final s in _h2StationsWithCoordinates) {
      if (s.stationName.toLowerCase().contains(lower)) {
        foundH2 = s;
        break;
      }
    }

    if (foundH2 != null) {
      final lat = foundH2.latitude!;
      final lng = foundH2.longitude!;
      unawaited(_focusTo(lat, lng));
      FocusScope.of(context).unfocus();
      _showH2StationBottomSheet(foundH2);
      return;
    }

    // 2) 없으면 EV에서 검색
    EVStation? foundEv;
    for (final s in _evStationsWithCoordinates) {
      if (s.stationName.toLowerCase().contains(lower)) {
        foundEv = s;
        break;
      }
    }

    if (foundEv != null) {
      final lat = foundEv.latitude!;
      final lng = foundEv.longitude!;
      unawaited(_focusTo(lat, lng));
      FocusScope.of(context).unfocus();
      _showEvStationBottomSheet(foundEv);
      return;
    }

    // 3) 둘 다 없으면 안내
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"$query" 이름의 충전소를 찾을 수 없습니다.')));
  }

  void _handleQuickAction(DynamicIslandAction action) {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    unawaited(_handleQuickActionAsync(action));
  }

  Future<void> _handleQuickActionAsync(DynamicIslandAction action) async {
    switch (action.type) {
      case 'parking':
        _ensureFilterForType(parking: true);
        await _focusAndOpen(action, onParking: _showParkingLotBottomSheet);
        break;
      case 'ev':
        _ensureFilterForType(ev: true);
        await _focusAndOpen(action, onEv: _showEvStationBottomSheet);
        break;
      case 'h2':
        _ensureFilterForType(h2: true);
        await _focusAndOpen(action, onH2: _showH2StationBottomSheet);
        break;
      default:
        break;
    }
  }

  Future<void> _focusAndOpen(
    DynamicIslandAction action, {
    void Function(ParkingLot lot)? onParking,
    void Function(EVStation station)? onEv,
    void Function(H2Station station)? onH2,
  }) async {
    final lat = action.lat;
    final lng = action.lng;
    if (lat != null && lng != null) {
      await _focusTo(lat, lng);
    }

    final payload = action.payload;
    if (payload is ParkingLot && onParking != null) {
      onParking(payload);
    } else if (payload is EVStation && onEv != null) {
      onEv(payload);
    } else if (payload is H2Station && onH2 != null) {
      onH2(payload);
    }
  }

  void _ensureFilterForType({
    bool h2 = false,
    bool ev = false,
    bool parking = false,
  }) {
    if (h2 && !_mapController.showH2) _mapController.toggleH2();
    if (ev && !_mapController.showEv) _mapController.toggleEv();
    if (parking && !_mapController.showParking) _mapController.toggleParking();
  }

  Future<void> _refreshDynamicIslandSuggestions() async {
    if (_isBuildingSuggestions || !_isSearchFocused) return;
    _isBuildingSuggestions = true;
    setState(() {});

    final position = await _getCurrentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _dynamicIslandActions = [];
        _isBuildingSuggestions = false;
      });
      return;
    }

    final actions = <DynamicIslandAction>[
      ..._buildNearestParking(position),
      ..._buildNearestEv(position),
      ..._buildNearestH2(position),
    ];

    setState(() {
      _dynamicIslandActions = actions;
      _isBuildingSuggestions = false;
    });
  }

  List<DynamicIslandAction> _buildNearestParking(
    Position position, {
    int take = 3,
  }) {
    final lots = _parkingLotsWithCoordinates.toList();
    lots.sort((a, b) {
      final da = _distance(position, a.latitude!, a.longitude!);
      final db = _distance(position, b.latitude!, b.longitude!);
      return da.compareTo(db);
    });

    return lots.take(take).map((lot) {
      final meters = _distance(position, lot.latitude!, lot.longitude!);
      return DynamicIslandAction(
        id: 'parking:${lot.id}',
        label: lot.name,
        subtitle: _formatDistance(meters),
        icon: Icons.local_parking,
        color: _parkingMarkerBaseColor,
        category: '근처 주차장',
        lat: lot.latitude,
        lng: lot.longitude,
        payload: lot,
        type: 'parking',
      );
    }).toList();
  }

  List<DynamicIslandAction> _buildNearestEv(Position position, {int take = 3}) {
    final stations = _evStationsWithCoordinates.toList();
    stations.sort((a, b) {
      final da = _distance(position, a.latitude!, a.longitude!);
      final db = _distance(position, b.latitude!, b.longitude!);
      return da.compareTo(db);
    });

    return stations.take(take).map((station) {
      final meters = _distance(position, station.latitude!, station.longitude!);
      return DynamicIslandAction(
        id: 'ev:${station.stationId}',
        label: station.stationName,
        subtitle: _formatDistance(meters),
        icon: Icons.ev_station,
        color: _evMarkerBaseColor,
        category: '근처 전기 충전소',
        lat: station.latitude,
        lng: station.longitude,
        payload: station,
        type: 'ev',
      );
    }).toList();
  }

  List<DynamicIslandAction> _buildNearestH2(Position position, {int take = 3}) {
    final stations = _h2StationsWithCoordinates.toList();
    stations.sort((a, b) {
      final da = _distance(position, a.latitude!, a.longitude!);
      final db = _distance(position, b.latitude!, b.longitude!);
      return da.compareTo(db);
    });

    return stations.take(take).map((station) {
      final meters = _distance(position, station.latitude!, station.longitude!);
      return DynamicIslandAction(
        id: 'h2:${station.stationId}',
        label: station.stationName,
        subtitle: _formatDistance(meters),
        icon: Icons.local_gas_station,
        color: _h2MarkerBaseColor,
        category: '근처 수소 충전소',
        lat: station.latitude,
        lng: station.longitude,
        payload: station,
        type: 'h2',
      );
    }).toList();
  }

  double _distance(Position origin, double lat, double lng) {
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      lat,
      lng,
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('위치 서비스를 켜주세요.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('위치 권한을 허용해주세요.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      return position;
    } catch (_) {
      _showSnack('현재 위치를 불러올 수 없습니다.');
      return null;
    }
  }

  Future<void> _focusTo(double lat, double lng) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.updateCamera(
      NCameraUpdate.fromCameraPosition(
        NCameraPosition(target: NLatLng(lat, lng), zoom: 14),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// 상단 중앙 로딩 토스트.
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
                  '위치 불러오는 중... (충전/주차)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 충전소 데이터를 불러오지 못했을 때 알림.
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
                  onPressed: _refreshStations,
                  child: const Text('재시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 사용자에게 부가 정보를 보여주는 공용 배너.
  Widget _buildInfoBanner({required IconData icon, required String message}) =>
      const SizedBox(); // migrated to InfoBanner widget

  /// 현재 표시 중인 마커의 개수를 보여주는 칩.
  Widget _buildStationsBadge() => const SizedBox(); // migrated to StationsBadge

  /// ⭐ 지도 위 H2 / EV / 주차 필터 토글 바
  Widget _buildFilterBar() {
    return const SizedBox(); // moved to FilterBar widget
  }

  /// 필터 아이콘 하나 (동그란 버튼 + 라벨)
  Widget _buildFilterIcon({
    required bool active,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return const SizedBox(); // migrated to FilterBar widget
  }

  /// 공통 필드 UI를 구성해 코드 중복을 줄인다.
  Widget _buildStationField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  String _formatParkingSpaces(ParkingLot lot) {
    final hasAvailable = lot.availableSpaces != null;
    final hasTotal = lot.totalSpaces != null;
    if (hasAvailable || hasTotal) {
      final available = hasAvailable ? lot.availableSpaces.toString() : '-';
      final total = hasTotal ? lot.totalSpaces.toString() : '-';
      return '$available / $total';
    }
    return '정보 없음';
  }

  // --- 지도 / 마커 관련 ---
  /// 지도 준비 완료 후 컨트롤러를 보관하고 첫 렌더링을 수행한다.
  void _handleMapReady(NaverMapController controller) {
    _controller = controller;
    unawaited(_renderStationMarkers());
  }

  void _handleMapLoaded() {
    _isMapLoaded = true;
    unawaited(_renderStationMarkers());
  }

  /// 지도에 표시할 모든 마커를 다시 생성하고 등록한다.
  Future<void> _renderStationMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      // 🔥 클러스터러블 마커 타입으로 지워야 함
      await controller.clearOverlays(type: NOverlayType.clusterableMarker);
      // 또는 완전히 싹 다 지우고 싶으면:
      // await controller.clearOverlays();
    } catch (_) {
      // 초기 로딩 동안은 컨트롤러 정리가 실패할 수 있으므로 무시한다.
    }

    final overlays = _mapController.buildMarkers(
      h2Builder: (station) => buildH2Marker(
        station: station,
        tint: _h2MarkerBaseColor,
        statusColor: _h2StatusColor,
        onTap: _showH2StationBottomSheet,
      ),
      evBuilder: (station) => buildEvMarker(
        station: station,
        tint: _evMarkerBaseColor,
        statusColor: _evStatusColor,
        onTap: _showEvStationBottomSheet,
      ),
      parkingBuilder: (lot) => buildParkingMarker(
        lot: lot,
        tint: _parkingMarkerBaseColor,
        onTap: _showParkingLotBottomSheet,
      ),
    );

    debugPrint(
      '🎯 Render markers (filtered): '
      'H2=${_mapController.showH2 ? _mapController.h2StationsWithCoords.length : 0}, '
      'EV=${_mapController.showEv ? _mapController.evStationsWithCoords.length : 0}, '
      'P=${_mapController.showParking ? _mapController.parkingLotsWithCoords.length : 0}',
    );

    if (overlays.isEmpty) return;
    try {
      await controller.addOverlayAll(overlays);
      if (Platform.isIOS) {
        // iOS에서 클러스터 마커가 갱신되지 않는 경우가 있어 강제 새로고침.
        await controller.forceRefresh();
      }
      debugPrint('✅ Added ${overlays.length} clusterable markers');
    } catch (error) {
      debugPrint('Marker overlay add failed: $error');
    }
  }

  Future<void> _refreshStations() async {
    if (_isManualRefreshing) return;
    setState(() => _isManualRefreshing = true);
    await _mapController.loadAllStations();
    if (!mounted) return;
    setState(() => _isManualRefreshing = false);
    if (_isMapLoaded && _controller != null) {
      unawaited(_renderStationMarkers());
    }
  }

  // --- 상태 색상 매핑 ---
  /// 수소 충전소 운영 상태 텍스트를 컬러로 매핑한다.
  Color _h2StatusColor(String statusName) {
    final normalized = statusName.trim();
    switch (normalized) {
      case '영업중':
        return Colors.blue;
      case '점검중':
      case 'T/T교체':
        return Colors.orange;
      case '영업중지':
        return Colors.redAccent;
      default:
        return Colors.indigo;
    }
  }

  /// 전기 충전소 상태 텍스트를 컬러로 매핑한다.
  Color _evStatusColor(String statusLabel) {
    final normalized = statusLabel.trim();
    switch (normalized) {
      case '충전대기':
        return Colors.green;
      case '충전중':
        return Colors.orange;
      case '점검중':
      case '고장':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  // --- ⭐ 즐겨찾기 서버 동기화(방법 1) ---
  Future<void> _syncFavoritesFromServer() async {
    String? accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('⭐ syncFavorites: 로그인 안 됨, 즐겨찾기 비움');
      if (!mounted) return;
      setState(() {
        _favoriteStationIds.clear();
      });
      return;
    }

    try {
      final url = Uri.parse('$_backendBaseUrl/api/me/favorites/stations');
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      debugPrint('⭐ 즐겨찾기 동기화 결과: ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          final ids = <String>{};
          for (final raw in body) {
            final map = raw as Map<String, dynamic>;
            final id = (map['stationId'] ?? map['id'] ?? '').toString();
            if (id.isNotEmpty) {
              ids.add(id);
            }
          }
          if (!mounted) return;
          setState(() {
            _favoriteStationIds
              ..clear()
              ..addAll(ids);
          });
        }
      } else {
        debugPrint('⭐ 즐겨찾기 동기화 실패: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('⭐ 즐겨찾기 동기화 오류: $e');
    }
  }

  // --- 바텀 시트 ---
  /// 수소 충전소 아이콘을 탭했을 때 상세 정보를 보여주는 바텀 시트.
  void _showH2StationBottomSheet(H2Station station) async {
    if (!mounted) return;

    // 🔁 바텀시트 열기 전에 서버 기준 즐겨찾기 동기화
    await _syncFavoritesFromServer();
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                  _buildStationField('대기 차량', '${station.waitingCount ?? 0}대'),
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
                  const SizedBox(height: 16),

                  /// 리뷰 버튼 (작성 / 목록)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.rate_review),
                          label: const Text('리뷰 작성하기'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReviewPage(
                                  stationId: station.stationId,
                                  placeName: station.stationName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.list_alt_rounded),
                          label: const Text('리뷰 목록'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReviewListPage(
                                  stationId: station.stationId,
                                  stationName: station.stationName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 주차장 마커를 탭했을 때 상세 정보를 보여주는 바텀 시트.
  void _showParkingLotBottomSheet(ParkingLot lot) {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lot.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStationField('주소', lot.address ?? '주소 정보 없음'),
              _buildStationField('주차 가능', _formatParkingSpaces(lot)),
              _buildStationField(
                '요금',
                lot.feeInfo?.isNotEmpty == true ? lot.feeInfo! : '요금 정보 없음',
              ),
              _buildStationField(
                '문의',
                lot.tel?.isNotEmpty == true ? lot.tel! : '연락처 정보 없음',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: const Text('리뷰 작성하기'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReviewPage(
                              stationId: lot.id,
                              placeName: lot.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.list_alt_rounded, size: 18),
                      label: const Text('리뷰 목록'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReviewListPage(
                              stationId: lot.id,
                              stationName: lot.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 전기 충전소 바텀 시트.
  void _showEvStationBottomSheet(EVStation station) {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.stationName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStationField(
                '상태',
                '${station.statusLabel} (${station.status})',
              ),
              _buildStationField(
                '출력',
                station.outputKw != null ? '${station.outputKw} kW' : '정보 없음',
              ),
              _buildStationField('최근 갱신', station.statusUpdatedAt ?? '정보 없음'),
              _buildStationField(
                '주소',
                '${station.address ?? ''} ${station.addressDetail ?? ''}'
                    .trim(),
              ),
              _buildStationField(
                '무료주차',
                station.parkingFree == true ? '예' : '아니요',
              ),
              _buildStationField(
                '층/구역',
                '${station.floor ?? '-'} / ${station.floorType ?? '-'}',
              ),
              const SizedBox(height: 16),

              /// 리뷰 버튼 (작성 / 목록)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('리뷰 작성하기'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReviewPage(
                              stationId: station.stationId,
                              placeName: station.stationName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text('리뷰 목록'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReviewListPage(
                              stationId: station.stationId,
                              stationName: station.stationName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- 즐겨찾기 관련 ---
  /// 현재 스테이션이 즐겨찾기인지 여부를 빠르게 확인한다.
  bool _isFavoriteStation(H2Station station) =>
      _favoriteStationIds.contains(station.stationId);

  /// 백엔드 즐겨찾기 API를 호출해 서버와 상태를 동기화한다.
  Future<void> _toggleFavoriteStation(H2Station station) async {
    final stationId = station.stationId;
    final isFav = _favoriteStationIds.contains(stationId);

    // 🔑 accessToken 안전하게 가져오기
    String? accessToken = await TokenStorage.getAccessToken();
    debugPrint('📦 MapScreen에서 읽은 accessToken: $accessToken');

    // secure storage가 write 완료되기 전에 접근할 경우 null일 수 있으므로 대기 추가
    if (accessToken == null || accessToken.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      accessToken = await TokenStorage.getAccessToken();
      debugPrint('🕐 재시도 후 accessToken: $accessToken');
    }

    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('❌ 즐겨찾기 실패: accessToken이 없습니다.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 즐겨찾기 기능을 사용할 수 있습니다.')),
        );
      }
      return;
    }

    final url = Uri.parse('$_backendBaseUrl/api/stations/$stationId/favorite');
    debugPrint('➡️ 즐겨찾기 API 호출: $url (isFav=$isFav)');

    try {
      http.Response res;
      if (!isFav) {
        res = await http.post(
          url,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        debugPrint('⬅️ POST 결과: ${res.statusCode} ${res.body}');
        if ([200, 201, 204].contains(res.statusCode)) {
          setState(() => _favoriteStationIds.add(stationId));
          debugPrint('✅ 즐겨찾기 추가 성공');
        } else {
          debugPrint('❌ 즐겨찾기 추가 실패: ${res.statusCode} ${res.body}');
        }
      } else {
        res = await http.delete(
          url,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        debugPrint('⬅️ DELETE 결과: ${res.statusCode} ${res.body}');
        if ([200, 204].contains(res.statusCode)) {
          setState(() => _favoriteStationIds.remove(stationId));
          debugPrint('✅ 즐겨찾기 해제 성공');
        } else {
          debugPrint('❌ 즐겨찾기 해제 실패: ${res.statusCode} ${res.body}');
        }
      }
    } catch (e) {
      debugPrint('❌ 즐겨찾기 중 오류: $e');
    }
  }

  /// 새로고침 FAB - 서버 상태를 다시 요청한다.
  void _onCenterButtonPressed() async {
    await _refreshStations();
  }
}
