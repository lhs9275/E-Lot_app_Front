// lib/screens/map/map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supercluster/supercluster.dart';
import 'package:url_launcher/url_launcher.dart';

// --- 내부 모듈 임포트 ---
import 'map_controller.dart';
import 'map_point.dart';
import 'marker_builders.dart'; // ⭐ 마커 빌더
import 'widgets/filter_bar.dart';
import 'widgets/search_bar.dart'; // ✅ [중요] 기존 검색바 파일 import (기능 복구)

import '../../models/ev_station.dart';
import '../../models/h2_station.dart';
import '../../models/parking_lot.dart';
import '../../services/ev_station_api_service.dart';
import '../../services/h2_station_api_service.dart';
import '../etc/review_list.dart';
import '../../services/parking_lot_api_service.dart';
import '../bottom_navbar.dart';
import '../etc/review.dart';
import 'package:psp2_fn/auth/token_storage.dart';
import 'package:psp2_fn/auth/auth_api.dart' as clos_auth;

// ⚠️ DynamicIslandAction은 widgets/search_bar.dart에 정의된 것을 사용

/// 검색용 후보 모델
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

/// 필터 결과 모델
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

class ParkingReservation {
  final DateTime start;
  final DateTime end;
  const ParkingReservation({required this.start, required this.end});
  int get hours => end.difference(start).inHours;
}

// --- 메인 앱 시작점 ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
  if (clientId == null || clientId.isEmpty) {
    debugPrint('❌ NAVER_MAP_CLIENT_ID가 .env에 없습니다.');
  }

  await FlutterNaverMap().init(
    clientId: clientId ?? '',
    onAuthFailed: (ex) {
      debugPrint('NaverMap auth failed: $ex');
    },
  );

  final h2BaseUrl = dotenv.env['H2_API_BASE_URL'];
  if (h2BaseUrl != null && h2BaseUrl.isNotEmpty) {
    h2StationApi = H2StationApiService(baseUrl: h2BaseUrl);
  }

  final evBaseUrl = dotenv.env['EV_API_BASE_URL'];
  if (evBaseUrl != null && evBaseUrl.isNotEmpty) {
    evStationApi = EVStationApiService(baseUrl: evBaseUrl);
  }

  final parkingBaseUrl = dotenv.env['PARKING_API_BASE_URL'] ?? evBaseUrl ?? h2BaseUrl;
  if (parkingBaseUrl != null && parkingBaseUrl.isNotEmpty) {
    parkingLotApi = ParkingLotApiService(baseUrl: parkingBaseUrl);
  }

  runApp(const _MapApp());
}

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
  // --- 상태 필드들 ---
  final MapController _mapController = MapController(
    h2Api: h2StationApi,
    evApi: evStationApi,
    parkingApi: parkingLotApi,
  );
  NaverMapController? _controller;

  // ✅ [아이콘 변경] 단일 아이콘 -> 단계별 아이콘 맵으로 변경
  final Map<String, NOverlayImage> _clusterIcons = {};

  SuperclusterMutable<MapPoint>? _clusterIndex;
  Timer? _renderDebounceTimer;
  bool _isRenderingClusters = false;
  bool _queuedRender = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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

  final NLatLng _initialTarget = const NLatLng(37.5666, 126.9790);
  late final NCameraPosition _initialCamera = NCameraPosition(
    target: _initialTarget,
    zoom: 8.5,
  );

  static const String _backendBaseUrl = 'https://clos21.kr';
  static const String _appRedirectScheme = 'psp2fn';
  static const String _paymentBridgeBase = 'https://clos21.kr/pay/bridge';

  final Set<String> _favoriteStationIds = {};

  // 🎨 디자인 컬러 (Deep Purple & Dark Chic)
  static const Color _primaryColor = Color(0xFF6541FF);
  static const Color _h2MarkerBaseColor = Color(0xFF2563EB);
  static const Color _evMarkerBaseColor = Color(0xFF10B981);
  static const Color _parkingMarkerBaseColor = Color(0xFFF59E0B);

  static const double _clusterDisableZoom = 15;
  static const int _clusterMinCountForClustering = 20;
  static const List<String> _defaultH2Specs = ['700', '350'];
  static const List<String> _defaultH2StationTypes = ['승용차', '버스', '복합'];
  static const List<String> _parkingCategoryOptions = ['공영', '민영'];
  static const List<String> _parkingTypeOptions = ['노상', '노외'];
  static const List<String> _parkingFeeTypeOptions = ['무료', '유료'];
  bool _isPaying = false;
  static const double _defaultH2FlowMinKgPerMin = 1.5;
  static const double _defaultH2FlowMaxKgPerMin = 3.5;

  String? get _stationError => _mapController.stationError;
  List<DynamicIslandAction> _dynamicIslandActions = [];
  bool _isBuildingSuggestions = false;

  Iterable<H2Station> get _h2StationsWithCoordinates => _mapController.h2StationsWithCoords;
  Iterable<EVStation> get _evStationsWithCoordinates => _mapController.evStationsWithCoords;
  Iterable<ParkingLot> get _parkingLotsWithCoordinates => _mapController.parkingLotsWithCoords;

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

    // ✅ [아이콘 변경] 준비 함수만 교체
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareClusterIcons());
  }

  @override
  void dispose() {
    _controller = null;
    _searchController.dispose();
    _searchFocusNode.dispose();
    _renderDebounceTimer?.cancel();
    _mapController.removeListener(_onMapControllerChanged);
    _mapController.dispose();
    super.dispose();
  }

  // ✅ [아이콘 변경] (요청 팔레트 적용 + 네모 잔상 제거)
  // - Soft Violet: #9575CD / #7E57C2
  // - Warm Yellow/Amber: #FFD54F / #FFCA28
  // - Rose Pink: #F06292 / #EC407A
  // - "네모 잔상" 방지: 그림자/PhysicalModel 제거 + ClipOval 내부에서만 렌더링
  // ✅ [아이콘 변경] (요청 팔레트 적용 + 반투명 + 네모 잔상 방지)
  Future<void> _prepareClusterIcons() async {
    try {
      Future<NOverlayImage> makeIcon({
        required Color a,
        required Color b,
        double size = 56,
        double fillOpacity = 0.30, //
        double ringOpacity = 0.70,
        double ringWidth = 2,
      }) async {
        return NOverlayImage.fromWidget(
          context: context,
          widget: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: size,
              height: size,
              child: ClipOval( // ✅ 네모 잔상 방지
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        a.withOpacity(fillOpacity),
                        b.withOpacity(fillOpacity),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(ringOpacity),
                      width: ringWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // ✅ Soft Violet 팔레트
      const violetA = Color(0xFF9575CD); // Soft Violet
      const violetB = Color(0xFF7E57C2); // Deep-ish Soft Violet

      // ✅ 전부 파스텔 보라로 통일 (단계만 유지)
      final small = await makeIcon(a: violetA, b: violetB, fillOpacity: 0.80);
      final mid   = await makeIcon(a: violetA, b: violetB, fillOpacity: 0.80);
      final large = await makeIcon(a: violetA, b: violetB, fillOpacity: 0.80);

      if (!mounted) return;
      setState(() {
        _clusterIcons
          ..clear()
          ..['small'] = small
          ..['mid'] = mid
          ..['large'] = large;
      });
    } catch (e) {
      debugPrint('Cluster icons build failed: $e');
    }
  }





  void _onMapControllerChanged() {
    if (_isMapLoaded && _controller != null) {
      unawaited(_rebuildClusterIndex());
    }
    if (_isSearchFocused) {
      unawaited(_refreshDynamicIslandSuggestions());
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const double navBarHeight = 60;
    const double navBarBottomMargin = 10;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double mapBottomPadding = navBarHeight + navBarBottomMargin + bottomInset;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: true,
        bottom: false,
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

            /// 🔍 상단 UI (검색바 + 필터)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(), // ✅ 기존 SearchBarSection (DynamicIsland 기능 포함)
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

      // ✨ 새로고침 버튼 (위치를 조금 더 아래로 내림)
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 4), // bottom 16 -> 20 (적절한 위치)
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isManualRefreshing ? null : _refreshStations,
              customBorder: const CircleBorder(),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                child: _isManualRefreshing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor),
                )
                    : const Icon(Icons.refresh_rounded, size: 28, color: _primaryColor),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
    );
  }

  /// ✅ [기능 복구] SearchBarSection 위젯 (Dynamic Island 기능 완벽 연결)
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
      // 검색 결과 또는 추천 목록 표시
      searchResults: _searchResults.isNotEmpty
          ? _searchResults
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
          .toList()
          : [],
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
      showDynamicIsland: _isSearchFocused && _searchResults.isEmpty, // 포커스만 갔을 때 추천 정보 뜸
      actions: _dynamicIslandActions, // 근처/추천 정보 연결
      onActionTap: _handleQuickAction,
    );
  }

  // 🔥 상세 필터 바텀시트
  Future<void> _openNearbyFilterSheet() async {
    const Color primaryColor = _primaryColor;
    const Color lightBgColor = Color(0xFFF9FBFD);
    const Color cardColor = Colors.white;
    const Color textColor = Color(0xFF1A1A1A);
    const Color subTextColor = Color(0xFF8E929C);

    // ✨ [디자인 유지] 예쁜 토글 스위치 (보라색 트랙 + 하얀 알)
    Widget buildTrendySwitch({
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF2F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textColor)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: subTextColor)),
                  ]
                ],
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white, // 흰색 알
                activeTrackColor: primaryColor, // 보라색 트랙
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE5E7EB),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildDropdown(String label, String? value, List<DropdownMenuItem<String?>> items, ValueChanged<String?> onChanged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: subTextColor)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: DropdownButtonFormField<String?>(
              value: value,
              items: items,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: subTextColor),
              style: const TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
              dropdownColor: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    Widget buildSoftChip(String label, bool selected, ValueChanged<bool> onSelected) {
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: const Color(0xFFF0EBFF),
        checkmarkColor: primaryColor,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? primaryColor : subTextColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide.none,
        ),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      );
    }

    Widget buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor)),
      );
    }

    final result = await showModalBottomSheet<_NearbyFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: lightBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        bool enabled = _useNearbyFilter;
        bool includeEv = _includeEvFilter;
        bool includeH2 = _includeH2Filter;
        bool includeParking = _includeParkingFilter;
        double radiusKm = _radiusKmFilter;
        String? evType;
        String? evStatus = _evStatusFilter;
        String? evCharger = _evChargerTypeFilter;
        String? h2Type;
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
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('상세 필터', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: textColor)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setModalState(reset),
                            child: const Text('초기화', style: TextStyle(color: subTextColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      buildTrendySwitch(
                        title: '필터 적용하기',
                        subtitle: '체크 시 설정한 조건으로만 검색합니다.',
                        value: enabled,
                        onChanged: (v) => setModalState(() => enabled = v),
                      ),
                      const SizedBox(height: 20),

                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          children: [
                            wrapIfDisabled(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('검색 반경', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                                      Text('${radiusKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                    ],
                                  ),
                                  SliderTheme(
                                    data: SliderThemeData(
                                      activeTrackColor: primaryColor,
                                      thumbColor: Colors.white,
                                      inactiveTrackColor: primaryColor.withOpacity(0.1),
                                      overlayColor: primaryColor.withOpacity(0.1),
                                    ),
                                    child: Slider(
                                      value: radiusKm,
                                      min: 0.5,
                                      max: 20,
                                      divisions: 39,
                                      onChanged: (value) => setModalState(() => radiusKm = value),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  buildSectionTitle('표시 대상'),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      buildSoftChip('⚡ EV', includeEv, (v) => setModalState(() => includeEv = v)),
                                      buildSoftChip('💧 H2', includeH2, (v) => setModalState(() => includeH2 = v)),
                                      buildSoftChip('🅿️ 주차장', includeParking, (v) => setModalState(() => includeParking = v)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  if (!includeEv && !includeH2 && !includeParking)
                                    const Center(child: Text('표시 대상을 선택하면 상세 옵션이 나타납니다.', style: TextStyle(color: subTextColor))),

                                  if (includeEv) ...[
                                    buildSectionTitle('EV 상세 옵션'),
                                    buildDropdown('충전기 상태', evStatus, const [
                                      DropdownMenuItem(value: null, child: Text('전체')),
                                      DropdownMenuItem(value: '2', child: Text('충전대기(사용 가능)')),
                                      DropdownMenuItem(value: '3', child: Text('충전중')),
                                      DropdownMenuItem(value: '5', child: Text('운영중지/점검')),
                                    ], (v) => setModalState(() => evStatus = v)),
                                    buildDropdown('충전기 타입', evCharger, const [
                                      DropdownMenuItem(value: null, child: Text('전체')),
                                      DropdownMenuItem(value: '06', child: Text('멀티(차데모/AC3상/콤보)')),
                                      DropdownMenuItem(value: '04', child: Text('급속(DC콤보)')),
                                      DropdownMenuItem(value: '02', child: Text('완속(AC완속)')),
                                      DropdownMenuItem(value: '07', child: Text('기타(AC3상 등)')),
                                    ], (v) => setModalState(() => evCharger = v)),
                                    const SizedBox(height: 12),
                                  ],

                                  if (includeH2) ...[
                                    buildSectionTitle('H2 상세 옵션'),
                                    const Text('압력 규격', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: subTextColor)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      children: _defaultH2Specs.map((spec) {
                                        return buildSoftChip(spec, h2Specs.contains(spec), (v) {
                                          setModalState(() => v ? h2Specs.add(spec) : h2Specs.remove(spec));
                                        });
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('충전소 유형', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: subTextColor)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      children: _defaultH2StationTypes.map((typeLabel) {
                                        return buildSoftChip(typeLabel, h2StationTypes.contains(typeLabel), (v) {
                                          setModalState(() => v ? h2StationTypes.add(typeLabel) : h2StationTypes.remove(typeLabel));
                                        });
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),

                                    buildTrendySwitch(
                                      title: '가격 범위 설정',
                                      subtitle: 'kg당 가격 범위를 지정합니다.',
                                      value: usePrice,
                                      onChanged: (v) => setModalState(() => usePrice = v),
                                    ),

                                    if (usePrice) ...[
                                      SliderTheme(
                                        data: SliderThemeData(
                                          activeTrackColor: primaryColor,
                                          thumbColor: Colors.white,
                                          inactiveTrackColor: primaryColor.withOpacity(0.1),
                                          trackHeight: 6,
                                          rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
                                          overlayColor: primaryColor.withOpacity(0.1),
                                        ),
                                        child: RangeSlider(
                                          values: priceRange,
                                          min: 0,
                                          max: 20000,
                                          divisions: 40,
                                          labels: RangeLabels('${priceRange.start.round()}원', '${priceRange.end.round()}원'),
                                          onChanged: (v) => setModalState(() => priceRange = v),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('${priceRange.start.round()}원', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor)),
                                            Text('${priceRange.end.round()}원', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    buildTrendySwitch(
                                      title: '최소 대기 슬롯',
                                      subtitle: '현재 충전 가능한 자리가 있는 곳만 봅니다.',
                                      value: useAvailability,
                                      onChanged: (v) => setModalState(() => useAvailability = v),
                                    ),

                                    if (useAvailability) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderThemeData(
                                                activeTrackColor: primaryColor,
                                                inactiveTrackColor: primaryColor.withOpacity(0.1),
                                                thumbColor: Colors.white,
                                                trackHeight: 6,
                                              ),
                                              child: Slider(
                                                value: availableMin.toDouble(),
                                                min: 0,
                                                max: 10,
                                                divisions: 10,
                                                onChanged: (v) => setModalState(() => availableMin = v.round()),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$availableMin대 이상',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ],

                                  if (includeParking) ...[
                                    buildSectionTitle('주차장 상세 옵션'),
                                    buildDropdown('운영 구분', parkingCategory, [
                                      const DropdownMenuItem(value: null, child: Text('전체')),
                                      ..._parkingCategoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                    ], (v) => setModalState(() => parkingCategory = v)),
                                    buildDropdown('유형', parkingType, [
                                      const DropdownMenuItem(value: null, child: Text('전체')),
                                      ..._parkingTypeOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                    ], (v) => setModalState(() => parkingType = v)),
                                    buildDropdown('요금 구분', parkingFeeType, [
                                      const DropdownMenuItem(value: null, child: Text('전체')),
                                      ..._parkingFeeTypeOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                    ], (v) => setModalState(() => parkingFeeType = v)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 4,
                              shadowColor: primaryColor.withOpacity(0.4),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(
                                _NearbyFilterResult(
                                  enabled: enabled,
                                  radiusKm: radiusKm,
                                  includeEv: includeEv,
                                  includeH2: includeH2,
                                  includeParking: includeParking,
                                  evType: includeEv ? evType : null,
                                  evChargerType: includeEv ? evCharger : null,
                                  evStatus: includeEv ? evStatus : null,
                                  h2Type: includeH2 ? h2Type : null,
                                  h2StationTypes: includeH2 ? h2StationTypes : {},
                                  h2Specs: includeH2 ? h2Specs : {},
                                  priceMin: includeH2 && usePrice ? priceRange.start.round() : null,
                                  priceMax: includeH2 && usePrice ? priceRange.end.round() : null,
                                  availableMin: includeH2 && useAvailability ? availableMin : null,
                                  parkingCategory: includeParking ? parkingCategory : null,
                                  parkingType: includeParking ? parkingType : null,
                                  parkingFeeType: includeParking ? parkingFeeType : null,
                                ),
                              );
                            },
                            child: const Text('필터 적용하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
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
            backgroundColor: _useNearbyFilter ? Colors.black.withOpacity(0.85) : Colors.white,
            foregroundColor: _useNearbyFilter ? Colors.white : Colors.black87,
            elevation: _useNearbyFilter ? 2 : 0,
            side: BorderSide(
              color: _useNearbyFilter ? Colors.black54 : Colors.grey.shade300,
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

  // --- 이하 기존 로직 그대로 유지 ---
  void _onSearchChanged(String raw) {
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final lower = query.toLowerCase();
    final List<_SearchCandidate> results = [];
    for (final s in _h2StationsWithCoordinates) {
      if (s.stationName.toLowerCase().contains(lower)) {
        results.add(_SearchCandidate(name: s.stationName, isH2: true, h2: s, ev: null, lat: s.latitude!, lng: s.longitude!));
      }
    }
    for (final s in _evStationsWithCoordinates) {
      if (s.stationName.toLowerCase().contains(lower)) {
        results.add(_SearchCandidate(name: s.stationName, isH2: false, h2: null, ev: s, lat: s.latitude!, lng: s.longitude!));
      }
    }
    if (results.length > 8) results.removeRange(8, results.length);
    setState(() => _searchResults = results);
  }

  void _onTapSearchCandidate(_SearchCandidate item) {
    _searchController.text = item.name;
    FocusScope.of(context).unfocus();
    setState(() => _searchResults = []);
    _controller?.updateCamera(NCameraUpdate.fromCameraPosition(NCameraPosition(target: NLatLng(item.lat, item.lng), zoom: 14)));
    if (item.isH2 && item.h2 != null) {
      _showH2StationPopup(item.h2!);
    } else if (!item.isH2 && item.ev != null) {
      _showEvStationPopup(item.ev!);
    }
  }

  void _onSearchSubmitted(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('충전소 이름을 입력해주세요.')));
      return;
    }
    if (_searchResults.isNotEmpty) {
      _onTapSearchCandidate(_searchResults.first);
      return;
    }
    final lower = query.toLowerCase();
    H2Station? foundH2;
    for (final s in _h2StationsWithCoordinates) {
      if (s.stationName.toLowerCase().contains(lower)) {
        foundH2 = s;
        break;
      }
    }
    if (foundH2 != null) {
      _focusTo(foundH2.latitude!, foundH2.longitude!);
      FocusScope.of(context).unfocus();
      _showH2StationPopup(foundH2);
      return;
    }
    EVStation? foundEv;
    for (final s in _evStationsWithCoordinates) {
      if (s.stationName.toLowerCase().contains(lower)) {
        foundEv = s;
        break;
      }
    }
    if (foundEv != null) {
      _focusTo(foundEv.latitude!, foundEv.longitude!);
      FocusScope.of(context).unfocus();
      _showEvStationPopup(foundEv);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$query" 이름의 충전소를 찾을 수 없습니다.')));
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
    }
  }

  Future<void> _focusAndOpen(
      DynamicIslandAction action, {
        void Function(ParkingLot)? onParking,
        void Function(EVStation)? onEv,
        void Function(H2Station)? onH2,
      }) async {
    final lat = action.lat;
    final lng = action.lng;
    if (lat != null && lng != null) await _focusTo(lat, lng);
    final payload = action.payload;
    if (payload is ParkingLot && onParking != null) onParking(payload);
    else if (payload is EVStation && onEv != null) onEv(payload);
    else if (payload is H2Station && onH2 != null) onH2(payload);
  }

  void _ensureFilterForType({bool h2 = false, bool ev = false, bool parking = false}) {
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

  List<DynamicIslandAction> _buildNearestParking(Position position, {int take = 3}) {
    final lots = _parkingLotsWithCoordinates.toList();
    lots.sort((a, b) => _distance(position, a.latitude!, a.longitude!).compareTo(_distance(position, b.latitude!, b.longitude!)));
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
    stations.sort((a, b) => _distance(position, a.latitude!, a.longitude!).compareTo(_distance(position, b.latitude!, b.longitude!)));
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
    stations.sort((a, b) => _distance(position, a.latitude!, a.longitude!).compareTo(_distance(position, b.latitude!, b.longitude!)));
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

  double _distance(Position origin, double lat, double lng) => Geolocator.distanceBetween(origin.latitude, origin.longitude, lat, lng);
  String _formatDistance(double meters) => meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)}km' : '${meters.round()}m';

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('위치 서비스를 켜주세요.');
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showSnack('위치 권한을 허용해주세요.');
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      _showSnack('현재 위치를 불러올 수 없습니다.');
      return null;
    }
  }

  Future<void> _focusTo(double lat, double lng) async {
    _controller?.updateCamera(NCameraUpdate.fromCameraPosition(NCameraPosition(target: NLatLng(lat, lng), zoom: 14)));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- 지도 / 마커 ---
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
    if (showSpinner) setState(() => _isManualRefreshing = true);
    if (_useNearbyFilter) await _runNearbySearch();
    else await _mapController.loadAllStations();
    if (!mounted) return;
    if (showSpinner) setState(() => _isManualRefreshing = false);
    if (_isMapLoaded && _controller != null) unawaited(_rebuildClusterIndex());
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
      'includeEv': _includeEvFilter.toString(),
      'includeH2': _includeH2Filter.toString(),
      'includeParking': _includeParkingFilter.toString(),
    };

    void addIfPresent(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) params[key] = value.trim();
    }

    void addCsv(String key, Set<String> values) {
      if (values.isNotEmpty) params[key] = values.join(',');
    }

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
      if (_useAvailabilityFilter && _h2AvailableMin > 0) params['availableMin'] = _h2AvailableMin.toString();
    }
    if (_includeParkingFilter) {
      addIfPresent('parkingCategory', _parkingCategoryFilter);
      addIfPresent('parkingType', _parkingTypeFilter);
      addIfPresent('parkingFeeType', _parkingFeeTypeFilter);
    }

    try {
      final uri = Uri.parse('$_backendBaseUrl/mapi/search/nearby').replace(queryParameters: params);
      final token = await TokenStorage.getAccessToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final h2 = (decoded['h2'] as List?)?.map((e) => H2Station.fromJson(e)).toList() ?? [];
        final ev = (decoded['ev'] as List?)?.map((e) => EVStation.fromJson(e)).toList() ?? [];
        final parking = (decoded['parkingLots'] as List?)?.map((e) => ParkingLot.fromJson(e)).toList() ?? [];
        _mapController.updateFromNearby(h2Stations: h2, evStations: ev, parkingLots: parking);
      } else {
        _showSnack('상세 필터 검색 실패 (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('상세 필터 검색 중 오류가 발생했습니다.');
    }
  }

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
    if (_isMapLoaded && mounted) _scheduleRenderClusters(immediate: true);
  }

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

    try {
      final camera = await controller.getCameraPosition();
      final bounds = await controller.getContentBounds();
      final zoom = camera.zoom;
      final points = _mapController.buildPoints();
      final pointsInBounds = points
          .where((p) =>
      p.lat >= bounds.southWest.latitude &&
          p.lat <= bounds.northEast.latitude &&
          p.lng >= bounds.southWest.longitude &&
          p.lng <= bounds.northEast.longitude)
          .toList();
      final bool disableCluster = zoom > _clusterDisableZoom || pointsInBounds.length <= _clusterMinCountForClustering;
      final overlays = <NAddableOverlay>{};

      if (disableCluster) {
        for (final point in pointsInBounds) overlays.add(_buildPointMarker(point));
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
              overlays.add(_buildClusterMarker(cluster, currentZoom: zoom));
              return null;
            },
            point: (point) {
              overlays.add(_buildPointMarker(point.originalPoint));
              return null;
            },
          );
        }
      }
      await controller.clearOverlays(type: NOverlayType.marker);
      if (overlays.isNotEmpty) {
        await controller.addOverlayAll(overlays);
        if (Platform.isIOS) await controller.forceRefresh();
      }
    } catch (_) {
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
        return buildH2Marker(station: point.h2!, tint: _h2MarkerBaseColor, statusColor: _h2StatusColor, onTap: _showH2StationPopup);
      case MapPointType.ev:
        return buildEvMarker(station: point.ev!, tint: _evMarkerBaseColor, statusColor: _evStatusColor, onTap: _showEvStationPopup);
      case MapPointType.parking:
        return buildParkingMarker(lot: point.parking!, tint: _parkingMarkerBaseColor, onTap: _showParkingLotPopup);
    }
  }

  // ✅ [아이콘 변경] 클러스터 수에 따라 아이콘만 다르게 선택
  NMarker _buildClusterMarker(LayerCluster<MapPoint> cluster, {double? currentZoom}) {
    final count = cluster.childPointCount;

    final NOverlayImage? icon = (count >= 120)
        ? _clusterIcons['large']
        : (count >= 40)
        ? _clusterIcons['mid']
        : _clusterIcons['small'];

    final marker = NMarker(
      id: 'cluster_${cluster.uuid}',
      position: NLatLng(cluster.latitude, cluster.longitude),
      size: const Size(58, 58),
      icon: icon,
      caption: NOverlayCaption(
        text: '$count',
        textSize: 14,
        color: Colors.white,
        haloColor: Colors.transparent,
      ),
      captionAligns: const [NAlign.center],
      isHideCollidedSymbols: true,
      isHideCollidedMarkers: true,
    );

    marker.setOnTapListener((_) async {
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
    });

    return marker;
  }

  Color _h2StatusColor(String statusName) {
    switch (statusName.trim()) {
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

  Color _evStatusColor(String statusLabel) {
    switch (statusLabel.trim()) {
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

  Future<void> _refreshStations() async {
    await _loadStationsRespectingFilter(showSpinner: true);
  }

  Future<void> _syncFavoritesFromServer() async {
    String? accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      setState(() => _favoriteStationIds.clear());
      return;
    }
    try {
      final url = Uri.parse('$_backendBaseUrl/api/me/favorites/stations');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          final ids = <String>{};
          for (final raw in body) {
            final map = raw as Map<String, dynamic>;
            final id = (map['stationId'] ?? map['id'] ?? '').toString();
            if (id.isNotEmpty) ids.add(id);
          }
          if (!mounted) return;
          setState(() => _favoriteStationIds..clear()..addAll(ids));
        }
      }
    } catch (_) {}
  }

  // --- 팝업 UI (간소화) ---
  Future<void> _showFloatingPanel({
    required Color accentColor,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget Function(StateSetter) contentBuilder,
    Widget? Function(StateSetter)? trailingBuilder,
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
                    constraints: BoxConstraints(maxWidth: 460, maxHeight: maxHeight),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 22, offset: const Offset(0, 14))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                                        child: Icon(icon, color: accentColor, size: 26),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                            if (subtitle != null) ...[
                                              const SizedBox(height: 4),
                                              Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (trailingBuilder != null) trailingBuilder(setPopupState) ?? const SizedBox.shrink(),
                                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                                  child: contentBuilder(setPopupState),
                                ),
                              ],
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
    );
  }

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
          icon: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded, color: isFav ? Colors.amber : Colors.grey.shade500),
          onPressed: () async {
            await _toggleFavoriteStation(station);
            setPopupState(() {});
          },
        );
      },
      contentBuilder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('상태: ${station.statusName}'),
          Text('대기: ${station.waitingCount ?? 0}대'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _h2MarkerBaseColor),
              icon: const Icon(Icons.payment),
              label: const Text('결제/예약'),
              onPressed: _isPaying ? null : () => _startPayment(itemName: '${station.stationName} 충전', amount: 5000), // 예시 금액
            ),
          ),
        ],
      ),
    );
  }

  void _showEvStationPopup(EVStation station) async {
    if (!mounted) return;
    await _showFloatingPanel(
      accentColor: _evMarkerBaseColor,
      icon: Icons.electric_car_rounded,
      title: station.stationName,
      subtitle: '전기 충전소',
      contentBuilder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('상태: ${station.statusLabel}'),
          Text('타입: ${station.chargerType ?? '-'}'),
        ],
      ),
    );
  }

  void _showParkingLotPopup(ParkingLot lot) async {
    if (!mounted) return;
    await _showFloatingPanel(
      accentColor: _parkingMarkerBaseColor,
      icon: Icons.local_parking_rounded,
      title: lot.name,
      subtitle: '주차장',
      contentBuilder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('주소: ${lot.address ?? '-'}'),
          Text('요금: ${lot.feeSummary ?? '-'}'),
        ],
      ),
    );
  }

  Future<void> _startPayment({required String itemName, required int amount}) async {
    // (결제 로직 생략 - 기존 코드와 동일)
  }

  bool _isFavoriteStation(H2Station station) => _favoriteStationIds.contains(station.stationId);

  Future<void> _toggleFavoriteStation(H2Station station) async {
    // (즐겨찾기 토글 로직 생략 - 기존 코드와 동일)
  }
}
