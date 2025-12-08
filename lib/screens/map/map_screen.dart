// lib/screens/map/map_screen.dart
import 'dart:async';
import 'dart:convert'; // ⭐ 즐겨찾기 동기화용 JSON 파싱
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supercluster/supercluster.dart';
import 'map_controller.dart';
import 'map_point.dart';
import 'marker_builders.dart';
import 'widgets/filter_bar.dart';
import 'widgets/search_bar.dart';

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

class _NearbyFilterResult {
  const _NearbyFilterResult({
    required this.enabled,
    required this.radiusKm,
    required this.includeEv,
    required this.includeH2,
    required this.includeParking,
    this.evType,
    this.evChargerType,
    this.evStatus,
    this.h2Type,
    this.h2StationTypes = const {},
    this.h2Specs = const {},
    this.priceMin,
    this.priceMax,
    this.availableMin,
    this.parkingCategory,
    this.parkingType,
    this.parkingFeeType,
  });

  final bool enabled;
  final double radiusKm;
  final bool includeEv;
  final bool includeH2;
  final bool includeParking;
  final String? evType;
  final String? evChargerType;
  final String? evStatus;
  final String? h2Type;
  final Set<String> h2StationTypes;
  final Set<String> h2Specs;
  final int? priceMin;
  final int? priceMax;
  final int? availableMin;
  final String? parkingCategory;
  final String? parkingType;
  final String? parkingFeeType;
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
  SuperclusterMutable<MapPoint>? _clusterIndex;
  Timer? _renderDebounceTimer;
  bool _isRenderingClusters = false;
  bool _queuedRender = false;

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

  // 상세 필터 상태
  bool _useNearbyFilter = false;
  bool _includeEvFilter = true;
  bool _includeH2Filter = true;
  bool _includeParkingFilter = true;
  double _radiusKmFilter = 5;

  String? _evTypeFilter;
  String? _evChargerTypeFilter;
  String? _evStatusFilter;

  String? _h2TypeFilter;
  final Set<String> _h2SpecFilter = {};
  final Set<String> _h2StationTypeFilter = {};
  int? _h2PriceMin;
  int? _h2PriceMax;
  int _h2AvailableMin = 0;
  bool _useAvailabilityFilter = false;

  String? _parkingCategoryFilter;
  String? _parkingTypeFilter;
  String? _parkingFeeTypeFilter;

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
  static const Color _clusterBaseColor = Color(0xFF111827); // 중성 짙은 슬레이트
  static const double _clusterDisableZoom = 15;
  static const int _clusterMinCountForClustering = 20; // 화면 내 포인트가 이 이하면 클러스터 해제
  static const List<String> _evApiTypes = ['ALL', 'CURRENT', 'OPERATION'];
  static const List<String> _h2ApiTypes = ['ALL', 'CURRENT', 'OPERATION'];
  static const List<String> _defaultH2Specs = ['700', '350'];
  static const List<String> _defaultH2StationTypes = ['승용차', '버스', '복합'];
  static const List<String> _parkingCategoryOptions = ['공영', '민영'];
  static const List<String> _parkingTypeOptions = ['노상', '노외'];
  static const List<String> _parkingFeeTypeOptions = ['무료', '유료'];

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

  List<String> get _evStatusOptions {
    final statuses = _mapController.evStations
        .map((e) => e.status)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    statuses.sort();
    return statuses;
  }

  List<String> get _evChargerTypeOptions {
    final chargers = _mapController.evStations
        .map((e) => e.chargerType)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    chargers.sort();
    return chargers;
  }

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
    _renderDebounceTimer?.cancel();
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
            color: _clusterBaseColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _clusterBaseColor.withOpacity(0.82),
              shape: BoxShape.circle,
            ),
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
      unawaited(_rebuildClusterIndex());
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
              onMapReady: _handleMapReady,
              onMapLoaded: _handleMapLoaded,
              onCameraChange: _handleCameraChange,
              onCameraIdle: _handleCameraIdle,
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
                  const SizedBox(height: 8),
                  _buildNearbyFilterButton(),
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
          _showH2StationPopup(item.h2 as H2Station);
        } else if (item.ev != null) {
          _showEvStationPopup(item.ev as EVStation);
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

  Future<void> _openNearbyFilterSheet() async {
    final evStatusOptions = _evStatusOptions;
    final evChargerOptions = _evChargerTypeOptions;

    final result = await showModalBottomSheet<_NearbyFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        bool enabled = _useNearbyFilter;
        bool includeEv = _includeEvFilter;
        bool includeH2 = _includeH2Filter;
        bool includeParking = _includeParkingFilter;
        double radiusKm = _radiusKmFilter;
        String? evType = _evTypeFilter;
        String? evStatus = _evStatusFilter;
        String? evCharger = _evChargerTypeFilter;
        String? h2Type = _h2TypeFilter;
        Set<String> h2Specs = {..._h2SpecFilter};
        Set<String> h2StationTypes = {..._h2StationTypeFilter};
        bool usePrice = _h2PriceMin != null || _h2PriceMax != null;
        RangeValues priceRange = RangeValues(
          (_h2PriceMin ?? 0).toDouble(),
          (_h2PriceMax ?? 15000).toDouble(),
        );
        bool useAvailability = _useAvailabilityFilter;
        int availableMin = _h2AvailableMin;
        String? parkingCategory = _parkingCategoryFilter;
        String? parkingType = _parkingTypeFilter;
        String? parkingFeeType = _parkingFeeTypeFilter;

        void reset() {
          enabled = false;
          includeEv = false;
          includeH2 = false;
          includeParking = false;
          radiusKm = 5;
          evType = null;
          evStatus = null;
          evCharger = null;
          h2Type = null;
          h2Specs.clear();
          h2StationTypes.clear();
          usePrice = false;
          priceRange = const RangeValues(0, 15000);
          useAvailability = false;
          availableMin = 0;
          parkingCategory = null;
          parkingType = null;
          parkingFeeType = null;
        }

        Widget wrapIfDisabled(Widget child) {
          if (enabled) return child;
          return Opacity(
            opacity: 0.45,
            child: IgnorePointer(child: child),
          );
        }

        InputDecoration inputDecoration(String label) {
          return InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              maxChildSize: 0.95,
              minChildSize: 0.6,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    top: 8,
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        children: [
                          Text(
                            '상세 필터',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setModalState(reset);
                            },
                            child: const Text('초기화'),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        onChanged: (v) {
                          setModalState(() {
                            enabled = v;
                          });
                        },
                        title: const Text('필터 켜기'),
                        subtitle: const Text('꺼져 있으면 전체 데이터를 불러옵니다.'),
                      ),
                      wrapIfDisabled(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              '검색 반경: ${radiusKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Slider(
                              value: radiusKm,
                              min: 0.5,
                              max: 20,
                              divisions: 39,
                              label: '${radiusKm.toStringAsFixed(1)}km',
                              onChanged: (value) {
                                setModalState(() {
                                  radiusKm = value;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '표시 대상',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FilterChip(
                                  label: const Text('EV'),
                                  selected: includeEv,
                                  onSelected: (v) {
                                    setModalState(() {
                                      includeEv = v;
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('H2'),
                                  selected: includeH2,
                                  onSelected: (v) {
                                    setModalState(() {
                                      includeH2 = v;
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('주차장'),
                                  selected: includeParking,
                                  onSelected: (v) {
                                    setModalState(() {
                                      includeParking = v;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (includeEv || includeH2 || includeParking)
                              const SizedBox.shrink()
                            else
                              const Text(
                                '표시 대상을 선택하면 옵션이 나타납니다.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            if (includeEv) ...[
                              Text(
                                'EV 옵션',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: evType,
                                decoration: inputDecoration('데이터 소스'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ..._evApiTypes.map(
                                        (t) => DropdownMenuItem<String?>(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setModalState(() => evType = value),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: evStatus,
                                decoration: inputDecoration('상태'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ...evStatusOptions.map(
                                        (s) => DropdownMenuItem<String?>(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setModalState(() => evStatus = value),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: evCharger,
                                decoration: inputDecoration('충전기 타입'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ...evChargerOptions.map(
                                        (s) => DropdownMenuItem<String?>(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setModalState(() => evCharger = value),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (includeH2) ...[
                              Text(
                                'H2 옵션',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: h2Type,
                                decoration: inputDecoration('데이터 소스'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ..._h2ApiTypes.map(
                                        (t) => DropdownMenuItem<String?>(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setModalState(() => h2Type = value),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '규격(SPEC)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _defaultH2Specs.map((spec) {
                                  final selected = h2Specs.contains(spec);
                                  return FilterChip(
                                    label: Text(spec),
                                    selected: selected,
                                    onSelected: (v) {
                                      setModalState(() {
                                        if (v) {
                                          h2Specs.add(spec);
                                        } else {
                                          h2Specs.remove(spec);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '충전소 유형',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children:
                                _defaultH2StationTypes.map((typeLabel) {
                                  final selected =
                                  h2StationTypes.contains(typeLabel);
                                  return FilterChip(
                                    label: Text(typeLabel),
                                    selected: selected,
                                    onSelected: (v) {
                                      setModalState(() {
                                        if (v) {
                                          h2StationTypes.add(typeLabel);
                                        } else {
                                          h2StationTypes.remove(typeLabel);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: usePrice,
                                onChanged: (v) {
                                  setModalState(() {
                                    usePrice = v;
                                  });
                                },
                                title: const Text('가격 필터 사용'),
                                subtitle:
                                const Text('kg당 가격 범위를 지정할 수 있습니다.'),
                              ),
                              if (usePrice) ...[
                                RangeSlider(
                                  values: priceRange,
                                  min: 0,
                                  max: 20000,
                                  divisions: 40,
                                  labels: RangeLabels(
                                    '${priceRange.start.round()}원',
                                    '${priceRange.end.round()}원',
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      priceRange = value;
                                    });
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '최소 ${priceRange.start.round()}원/kg'),
                                    Text(
                                        '최대 ${priceRange.end.round()}원/kg'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: useAvailability,
                                onChanged: (v) {
                                  setModalState(() {
                                    useAvailability = v;
                                  });
                                },
                                title: const Text('가용 슬롯 필터'),
                                subtitle: const Text('동시 충전 가능 대수 기준'),
                              ),
                              if (useAvailability)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Slider(
                                      value: availableMin.toDouble(),
                                      min: 0,
                                      max: 10,
                                      divisions: 10,
                                      label: '$availableMin대 이상',
                                      onChanged: (value) {
                                        setModalState(() {
                                          availableMin = value.round();
                                        });
                                      },
                                    ),
                                    Text(
                                      '$availableMin대 이상',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                            ],
                            if (includeParking) ...[
                              Text(
                                '주차장 옵션',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: parkingCategory,
                                decoration: inputDecoration('구분'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ..._parkingCategoryOptions.map(
                                        (c) => DropdownMenuItem<String?>(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setModalState(() => parkingCategory = value),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: parkingType,
                                decoration: inputDecoration('유형'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ..._parkingTypeOptions.map(
                                        (c) => DropdownMenuItem<String?>(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setModalState(() => parkingType = value),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: parkingFeeType,
                                decoration: inputDecoration('요금'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('전체'),
                                  ),
                                  ..._parkingFeeTypeOptions.map(
                                        (c) => DropdownMenuItem<String?>(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setModalState(
                                        () => parkingFeeType = value),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(reset);
                            },
                            child: const Text('초기화'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('적용'),
                            onPressed: () {
                              Navigator.of(context).pop(
                                _NearbyFilterResult(
                                  enabled: enabled,
                                  radiusKm: radiusKm,
                                  includeEv: includeEv,
                                  includeH2: includeH2,
                                  includeParking: includeParking,
                                  evType: includeEv ? evType : null,
                                  evChargerType:
                                  includeEv ? evCharger : null,
                                  evStatus: includeEv ? evStatus : null,
                                  h2Type: includeH2 ? h2Type : null,
                                  h2StationTypes:
                                  includeH2 ? h2StationTypes : {},
                                  h2Specs: includeH2 ? h2Specs : {},
                                  priceMin: includeH2 && usePrice
                                      ? priceRange.start.round()
                                      : null,
                                  priceMax: includeH2 && usePrice
                                      ? priceRange.end.round()
                                      : null,
                                  availableMin:
                                  includeH2 && useAvailability
                                      ? availableMin
                                      : null,
                                  parkingCategory:
                                  includeParking ? parkingCategory : null,
                                  parkingType:
                                  includeParking ? parkingType : null,
                                  parkingFeeType: includeParking
                                      ? parkingFeeType
                                      : null,
                                ),
                              );
                            },
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
      },
    );

    if (result == null) return;

    if (!result.enabled) {
      setState(() {
        _useNearbyFilter = false;
        _includeEvFilter = true;
        _includeH2Filter = true;
        _includeParkingFilter = true;
      });
      await _loadStationsRespectingFilter(showSpinner: true);
      return;
    }

    setState(() {
      _useNearbyFilter = true;
      _radiusKmFilter = result.radiusKm;
      _includeEvFilter = result.includeEv;
      _includeH2Filter = result.includeH2;
      _includeParkingFilter = result.includeParking;
      _evTypeFilter = result.evType;
      _evChargerTypeFilter = result.evChargerType;
      _evStatusFilter = result.evStatus;
      _h2TypeFilter = result.h2Type;
      _h2SpecFilter
        ..clear()
        ..addAll(result.h2Specs);
      _h2StationTypeFilter
        ..clear()
        ..addAll(result.h2StationTypes);
      _h2PriceMin = result.priceMin;
      _h2PriceMax = result.priceMax;
      _useAvailabilityFilter = result.availableMin != null;
      _h2AvailableMin = result.availableMin ?? 0;
      _parkingCategoryFilter = result.parkingCategory;
      _parkingTypeFilter = result.parkingType;
      _parkingFeeTypeFilter = result.parkingFeeType;
    });

    await _loadStationsRespectingFilter(showSpinner: true);
  }

  Widget _buildNearbyFilterButton() {
    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            backgroundColor:
            _useNearbyFilter ? Colors.black.withOpacity(0.85) : Colors.white,
            foregroundColor:
            _useNearbyFilter ? Colors.white : Colors.black87,
            elevation: _useNearbyFilter ? 2 : 0,
            side: BorderSide(
              color:
              _useNearbyFilter ? Colors.black54 : Colors.grey.shade300,
            ),
          ),
          onPressed: _openNearbyFilterSheet,
          icon: const Icon(Icons.tune),
          label: Text(_useNearbyFilter ? '필터 수정' : '상세 필터'),
        ),
        const SizedBox(width: 8),
        if (_useNearbyFilter)
          Flexible(
            child: Text(
              '적용 반경 ${_radiusKmFilter.toStringAsFixed(1)}km',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
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
      _showH2StationPopup(item.h2!);
    } else if (!item.isH2 && item.ev != null) {
      _showEvStationPopup(item.ev!);
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
      _showH2StationPopup(foundH2);
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
      _showEvStationPopup(foundEv);
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
        await _focusAndOpen(action, onParking: _showParkingLotPopup);
        break;
      case 'ev':
        _ensureFilterForType(ev: true);
        await _focusAndOpen(action, onEv: _showEvStationPopup);
        break;
      case 'h2':
        _ensureFilterForType(h2: true);
        await _focusAndOpen(action, onH2: _showH2StationPopup);
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
    unawaited(_rebuildClusterIndex());
  }

  void _handleMapLoaded() {
    _isMapLoaded = true;
    unawaited(_rebuildClusterIndex());
  }

  void _handleCameraChange(NCameraUpdateReason reason, bool isAnimated) {
    _scheduleRenderClusters();
  }

  void _handleCameraIdle() {
    _scheduleRenderClusters(immediate: true);
  }

  Future<void> _loadStationsRespectingFilter({bool showSpinner = false}) async {
    if (_isManualRefreshing && showSpinner) return;
    if (showSpinner) {
      setState(() => _isManualRefreshing = true);
    }
    if (_useNearbyFilter) {
      await _runNearbySearch();
    } else {
      await _mapController.loadAllStations();
    }
    if (!mounted) return;
    if (showSpinner) {
      setState(() => _isManualRefreshing = false);
    }
    if (_isMapLoaded && _controller != null) {
      unawaited(_rebuildClusterIndex());
    }
  }

  Future<void> _runNearbySearch() async {
    final position = await _getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      _showSnack('GPS 위치를 가져올 수 없어 전체 데이터를 유지합니다.');
      return;
    }

    final params = <String, String>{
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
      'radius': (_radiusKmFilter * 1000).round().toString(),
    };

    void addIfPresent(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    void addCsv(String key, Set<String> values) {
      if (values.isNotEmpty) {
        params[key] = values.join(',');
      }
    }

    // 포함 여부
    params['includeEv'] = _includeEvFilter.toString();
    params['includeH2'] = _includeH2Filter.toString();
    params['includeParking'] = _includeParkingFilter.toString();

    if (_includeEvFilter) {
      addIfPresent('evType', _evTypeFilter == 'ALL' ? null : _evTypeFilter);
      addIfPresent('evChargerType', _evChargerTypeFilter);
      addIfPresent('evStatus', _evStatusFilter);
    }

    if (_includeH2Filter) {
      addIfPresent('h2Type', _h2TypeFilter == 'ALL' ? null : _h2TypeFilter);
      addCsv('stationType', _h2StationTypeFilter);
      addCsv('spec', _h2SpecFilter);
      if (_h2PriceMin != null) params['priceMin'] = _h2PriceMin.toString();
      if (_h2PriceMax != null) params['priceMax'] = _h2PriceMax.toString();
      if (_useAvailabilityFilter && _h2AvailableMin > 0) {
        params['availableMin'] = _h2AvailableMin.toString();
      }
    }

    if (_includeParkingFilter) {
      addIfPresent('parkingCategory', _parkingCategoryFilter);
      addIfPresent('parkingType', _parkingTypeFilter);
      addIfPresent('parkingFeeType', _parkingFeeTypeFilter);
    }

    try {
      final uri = Uri.parse('$_backendBaseUrl/mapi/search/nearby')
          .replace(queryParameters: params);
      final token = await TokenStorage.getAccessToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final h2 = (decoded['h2'] as List?)
                ?.map((e) => H2Station.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <H2Station>[];
        final ev = (decoded['ev'] as List?)
                ?.map((e) => EVStation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <EVStation>[];
        final parking = (decoded['parkingLots'] as List?)
                ?.map((e) => ParkingLot.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <ParkingLot>[];
        _mapController.updateFromNearby(
          h2Stations: h2,
          evStations: ev,
          parkingLots: parking,
        );
      } else {
        debugPrint('Nearby search failed: ${res.statusCode} ${res.body}');
        _showSnack('상세 필터 검색 실패 (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('Nearby search error: $e');
      _showSnack('상세 필터 검색 중 오류가 발생했습니다.');
    }
  }

  /// 데이터 필터링 상태에 맞춰 클러스터 인덱스를 다시 구축하고, 현재 뷰포트에 표시한다.
  Future<void> _rebuildClusterIndex() async {
    final points = _mapController.buildPoints();
    final index = SuperclusterMutable<MapPoint>(
      getX: (p) => p.lng,
      getY: (p) => p.lat,
      minZoom: 0,
      maxZoom: 16,
      radius: 60,
    )..load(points);
    _clusterIndex = index;

    debugPrint('🎯 Rebuilt cluster index with ${points.length} points');
    if (_isMapLoaded && mounted) {
      _scheduleRenderClusters(immediate: true);
    }
  }

  /// 카메라 이동 시 클러스터 렌더를 디바운스해 과도한 호출을 막는다.
  void _scheduleRenderClusters({bool immediate = false}) {
    if (_clusterIndex == null || !_isMapLoaded) return;

    if (immediate) {
      _renderDebounceTimer?.cancel();
      unawaited(_renderVisibleClusters());
      return;
    }

    _renderDebounceTimer?.cancel();
    _renderDebounceTimer = Timer(const Duration(milliseconds: 80), () {
      unawaited(_renderVisibleClusters());
    });
  }

  Future<void> _renderVisibleClusters() async {
    final controller = _controller;
    final index = _clusterIndex;
    if (controller == null || index == null) return;
    if (_isRenderingClusters) {
      _queuedRender = true;
      return;
    }

    _isRenderingClusters = true;

    NCameraPosition camera;
    NLatLngBounds bounds;
    try {
      camera = await controller.getCameraPosition();
      bounds = await controller.getContentBounds();
    } catch (e) {
      debugPrint('Camera/bounds fetch failed: $e');
      return;
    }

    final double zoom = camera.zoom;
    final points = _mapController.buildPoints();
    final pointsInBounds =
        points.where((p) => _isPointInBounds(p, bounds)).toList();

    final bool disableCluster = zoom > _clusterDisableZoom ||
        pointsInBounds.length <= _clusterMinCountForClustering;
    final overlays = <NAddableOverlay>{};

    if (disableCluster) {
      // 고배율에서는 클러스터를 해제하고 개별 포인트만 표시.
      for (final point in pointsInBounds) {
        overlays.add(_buildPointMarker(point));
      }
    } else {
      final int intZoom = zoom.round().clamp(index.minZoom, index.maxZoom);
      final elements = index.search(
        bounds.southWest.longitude,
        bounds.southWest.latitude,
        bounds.northEast.longitude,
        bounds.northEast.latitude,
        intZoom,
      );

      for (final element in elements) {
        element.handle(
          cluster: (cluster) {
            overlays.add(
              _buildClusterMarker(cluster, currentZoom: zoom),
            );
            return null;
          },
          point: (point) {
            overlays.add(_buildPointMarker(point.originalPoint));
            return null;
          },
        );
      }
    }

    try {
      await controller.clearOverlays(type: NOverlayType.marker);
      if (overlays.isEmpty) return;
      await controller.addOverlayAll(overlays);
      if (Platform.isIOS) {
        await controller.forceRefresh();
      }
      debugPrint(
        '✅ Added ${overlays.length} markers (zoom ${camera.zoom.toStringAsFixed(1)})',
      );
    } catch (error) {
      debugPrint('Marker overlay add failed: $error');
    } finally {
      _isRenderingClusters = false;
      if (_queuedRender) {
        _queuedRender = false;
        unawaited(_renderVisibleClusters());
      }
    }
  }

  NMarker _buildPointMarker(MapPoint point) {
    switch (point.type) {
      case MapPointType.h2:
        return buildH2Marker(
          station: point.h2!,
          tint: _h2MarkerBaseColor,
          statusColor: _h2StatusColor,
          onTap: _showH2StationPopup,
        );
      case MapPointType.ev:
        return buildEvMarker(
          station: point.ev!,
          tint: _evMarkerBaseColor,
          statusColor: _evStatusColor,
          onTap: _showEvStationPopup,
        );
      case MapPointType.parking:
        return buildParkingMarker(
          lot: point.parking!,
          tint: _parkingMarkerBaseColor,
          onTap: _showParkingLotPopup,
        );
    }
  }

  NMarker _buildClusterMarker(
    LayerCluster<MapPoint> cluster, {
    double? currentZoom,
  }) {
    final count = cluster.childPointCount;
    final marker = NMarker(
      id: 'cluster_${cluster.uuid}',
      position: NLatLng(cluster.latitude, cluster.longitude),
      size: const Size(56, 56),
      icon: _clusterIcon,
      caption: NOverlayCaption(
        text: '$count',
        textSize: 13,
        color: Colors.white,
        haloColor: Colors.black.withOpacity(0.35),
      ),
      captionAligns: const [NAlign.center],
      isHideCollidedSymbols: true,
      isHideCollidedMarkers: true,
    );
    marker.setOnTapListener(
      (_) => _zoomIntoCluster(cluster, currentZoom: currentZoom),
    );
    return marker;
  }

  bool _isPointInBounds(MapPoint point, NLatLngBounds bounds) {
    return point.lat >= bounds.southWest.latitude &&
        point.lat <= bounds.northEast.latitude &&
        point.lng >= bounds.southWest.longitude &&
        point.lng <= bounds.northEast.longitude;
  }

  Future<void> _zoomIntoCluster(
    LayerCluster<MapPoint> cluster, {
    double? currentZoom,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    double zoom = currentZoom ?? (await controller.getCameraPosition()).zoom;
    zoom = (zoom + 1.5).clamp(0, 20);

    await controller.updateCamera(
      NCameraUpdate.fromCameraPosition(
        NCameraPosition(
          target: NLatLng(cluster.latitude, cluster.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> _refreshStations() async {
    await _loadStationsRespectingFilter(showSpinner: true);
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

  // --- 팝업 UI (마커 상세) ---
  Future<void> _showFloatingPanel({
    required Color accentColor,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget Function(StateSetter setState) contentBuilder,
    Widget? Function(StateSetter setState)? trailingBuilder,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        final maxHeight = MediaQuery.of(context).size.height * 0.75;
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: StatefulBuilder(
                builder: (context, setPopupState) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 460,
                      maxHeight: maxHeight,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.08),
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Material(
                            color: Colors.white.withOpacity(0.94),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.zero,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(18, 16, 12, 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildPopupIcon(icon, accentColor),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: -0.2,
                                                    ),
                                              ),
                                              if (subtitle != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitle!,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (trailingBuilder != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: trailingBuilder(setPopupState),
                                          ),
                                        IconButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(
                                    height: 1,
                                    thickness: 0.7,
                                    indent: 12,
                                    endIndent: 12,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      12,
                                      18,
                                      14,
                                    ),
                                    child: contentBuilder(setPopupState),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        return Transform.translate(
          offset: Offset(0, (1 - curved) * 18),
          child: Transform.scale(
            scale: 0.96 + 0.04 * curved,
            child: Opacity(
              opacity: curved,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupIcon(IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: accentColor, size: 26),
    );
  }

  Widget _buildPopupChip(
    String text, {
    IconData? icon,
    Color? color,
    Color? textColor,
  }) {
    final resolvedTextColor = textColor ?? Colors.grey.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (textColor ?? Colors.black87).withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: resolvedTextColor),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: resolvedTextColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupActions({
    required Color accentColor,
    required VoidCallback onWriteReview,
    required VoidCallback onSeeReviews,
  }) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.rate_review_rounded),
            label: const Text('리뷰 작성'),
            onPressed: onWriteReview,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: accentColor.withOpacity(0.65)),
              foregroundColor: accentColor,
            ),
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('리뷰 목록'),
            onPressed: onSeeReviews,
          ),
        ),
      ],
    );
  }

  /// 수소 충전소 아이콘을 탭했을 때 떠 있는 카드 형태로 상세 정보를 보여준다.
  void _showH2StationPopup(H2Station station) async {
    if (!mounted) return;

    await _syncFavoritesFromServer();
    if (!mounted) return;

    await _showFloatingPanel(
      accentColor: _h2MarkerBaseColor,
      icon: Icons.local_gas_station_rounded,
      title: station.stationName,
      subtitle: '수소 충전소',
      trailingBuilder: (setPopupState) {
        final isFav = _isFavoriteStation(station);
        return IconButton(
          tooltip: '즐겨찾기',
          icon: Icon(
            isFav ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFav ? Colors.amber : Colors.grey.shade500,
          ),
          onPressed: () async {
            await _toggleFavoriteStation(station);
            setPopupState(() {});
          },
        );
      },
      contentBuilder: (_) {
        final statusColor = _h2StatusColor(station.statusName);
        final waiting = station.waitingCount ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPopupChip(
                  station.statusName,
                  icon: Icons.circle,
                  color: statusColor.withOpacity(0.14),
                  textColor: statusColor,
                ),
                _buildPopupChip(
                  '대기 $waiting대',
                  icon: Icons.hourglass_bottom_rounded,
                  color: Colors.blueGrey.shade50,
                ),
                if (station.maxChargeCount != null)
                  _buildPopupChip(
                    '최대 ${station.maxChargeCount}대 동시',
                    icon: Icons.ev_station_rounded,
                    color: Colors.blueGrey.shade50,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPopupInfoRow(
              icon: Icons.bolt_rounded,
              label: '운영 상태',
              value: station.statusName,
              valueColor: statusColor,
            ),
            _buildPopupInfoRow(
              icon: Icons.timer_rounded,
              label: '최종 갱신',
              value: station.lastModifiedAt ?? '정보 없음',
            ),
            _buildPopupInfoRow(
              icon: Icons.analytics_outlined,
              label: '최대 충전 가능',
              value: station.maxChargeCount != null
                  ? '${station.maxChargeCount}대'
                  : '정보 없음',
            ),
            _buildPopupInfoRow(
              icon: Icons.groups_rounded,
              label: '대기 차량',
              value: '$waiting대',
            ),
            const SizedBox(height: 16),
            _buildPopupActions(
              accentColor: _h2MarkerBaseColor,
              onWriteReview: () {
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
              onSeeReviews: () {
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
          ],
        );
      },
    );
  }

  /// 주차장 마커를 탭했을 때 떠 있는 카드 형태로 상세 정보를 보여준다.
  void _showParkingLotPopup(ParkingLot lot) async {
    if (!mounted) return;

    await _showFloatingPanel(
      accentColor: _parkingMarkerBaseColor,
      icon: Icons.local_parking_rounded,
      title: lot.name,
      subtitle: '주차장 정보',
      contentBuilder: (_) {
        final availability = _formatParkingSpaces(lot);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPopupChip(
                  availability,
                  icon: Icons.event_available_rounded,
                  color: Colors.orange.shade50,
                  textColor: Colors.deepOrange,
                ),
                if (lot.feeInfo != null && lot.feeInfo!.isNotEmpty)
                  _buildPopupChip(
                    lot.feeInfo!,
                    icon: Icons.payments_rounded,
                    color: Colors.blueGrey.shade50,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPopupInfoRow(
              icon: Icons.place_rounded,
              label: '주소',
              value: lot.address ?? '주소 정보 없음',
            ),
            _buildPopupInfoRow(
              icon: Icons.call_rounded,
              label: '문의',
              value: lot.tel?.isNotEmpty == true ? lot.tel! : '연락처 정보 없음',
            ),
            _buildPopupInfoRow(
              icon: Icons.local_activity_rounded,
              label: '총 주차면수',
              value: lot.totalSpaces != null
                  ? '${lot.totalSpaces}면'
                  : '정보 없음',
            ),
            const SizedBox(height: 16),
            _buildPopupActions(
              accentColor: _parkingMarkerBaseColor,
              onWriteReview: () {
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
              onSeeReviews: () {
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
          ],
        );
      },
    );
  }

  /// 전기 충전소 상세 팝업.
  void _showEvStationPopup(EVStation station) async {
    if (!mounted) return;

    await _showFloatingPanel(
      accentColor: _evMarkerBaseColor,
      icon: Icons.electric_car_rounded,
      title: station.stationName,
      subtitle: '전기 충전소',
      contentBuilder: (_) {
        final statusColor = _evStatusColor(station.statusLabel);
        final outputText =
            station.outputKw != null ? '${station.outputKw} kW' : '정보 없음';
        final rawAddress =
            '${station.address ?? ''} ${station.addressDetail ?? ''}'.trim();
        final address =
            rawAddress.isNotEmpty ? rawAddress : '주소 정보 없음';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPopupChip(
                  station.statusLabel,
                  icon: Icons.circle,
                  color: statusColor.withOpacity(0.14),
                  textColor: statusColor,
                ),
                _buildPopupChip(
                  '출력 $outputText',
                  icon: Icons.bolt_rounded,
                  color: Colors.blueGrey.shade50,
                ),
                _buildPopupChip(
                  station.parkingFree == true ? '무료 주차' : '유료 주차',
                  icon: Icons.local_parking_rounded,
                  color: Colors.blueGrey.shade50,
                  textColor: station.parkingFree == true
                      ? _evMarkerBaseColor
                      : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPopupInfoRow(
              icon: Icons.power_rounded,
              label: '충전 방식',
              value: '${station.statusLabel} (${station.status})',
              valueColor: statusColor,
            ),
            _buildPopupInfoRow(
              icon: Icons.timer_outlined,
              label: '최근 갱신',
              value: station.statusUpdatedAt ?? '정보 없음',
            ),
            _buildPopupInfoRow(
              icon: Icons.place_rounded,
              label: '주소',
              value: address,
            ),
            _buildPopupInfoRow(
              icon: Icons.layers_rounded,
              label: '층/구역',
              value: '${station.floor ?? '-'} / ${station.floorType ?? '-'}',
            ),
            const SizedBox(height: 16),
            _buildPopupActions(
              accentColor: _evMarkerBaseColor,
              onWriteReview: () {
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
              onSeeReviews: () {
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
          ],
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
