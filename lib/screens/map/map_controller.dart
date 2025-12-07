import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../models/ev_station.dart';
import '../../models/h2_station.dart';
import '../../models/parking_lot.dart';
import '../../services/ev_station_api_service.dart';
import '../../services/h2_station_api_service.dart';
import '../../services/parking_lot_api_service.dart';

/// 지도 상태(데이터/필터/로딩)를 관리하는 ChangeNotifier.
class MapController extends ChangeNotifier {
  MapController({
    required H2StationApiService h2Api,
    required EVStationApiService evApi,
    required ParkingLotApiService parkingApi,
  })  : _h2Api = h2Api,
        _evApi = evApi,
        _parkingApi = parkingApi;

  final H2StationApiService _h2Api;
  final EVStationApiService _evApi;
  final ParkingLotApiService _parkingApi;

  // --- 상태 필드 ---
  List<H2Station> _h2Stations = [];
  List<EVStation> _evStations = [];
  List<ParkingLot> _parkingLots = [];

  bool _isLoadingH2 = true;
  bool _isLoadingEv = true;
  bool _isLoadingParking = true;
  String? _stationError;

  bool _showH2 = true;
  bool _showEv = true;
  bool _showParking = true;

  bool get showH2 => _showH2;
  bool get showEv => _showEv;
  bool get showParking => _showParking;

  List<H2Station> get h2Stations => _h2Stations;
  List<EVStation> get evStations => _evStations;
  List<ParkingLot> get parkingLots => _parkingLots;

  bool get isLoading =>
      _isLoadingH2 || _isLoadingEv || _isLoadingParking;
  String? get stationError => _stationError;

  Iterable<H2Station> get h2StationsWithCoords =>
      _h2Stations.where((s) => s.latitude != null && s.longitude != null);
  Iterable<EVStation> get evStationsWithCoords =>
      _evStations.where((s) => s.latitude != null && s.longitude != null);
  Iterable<ParkingLot> get parkingLotsWithCoords =>
      _parkingLots.where((s) => s.latitude != null && s.longitude != null);

  int get totalMappableCount {
    var count = 0;
    if (_showH2) count += h2StationsWithCoords.length;
    if (_showEv) count += evStationsWithCoords.length;
    if (_showParking) count += parkingLotsWithCoords.length;
    return count;
  }

  // --- 동작 ---
  Future<void> loadAllStations() async {
    _isLoadingH2 = _isLoadingEv = _isLoadingParking = true;
    _stationError = null;
    notifyListeners();
    await Future.wait([
      _loadH2(),
      _loadEv(),
      _loadParking(),
    ]);
  }

  Future<void> _loadH2() async {
    try {
      final stations = await _h2Api.fetchStations();
      _h2Stations = stations;
      _isLoadingH2 = false;
    } catch (e) {
      _isLoadingH2 = false;
      _stationError ??= '수소 충전소 데이터를 불러오지 못했습니다.';
    }
    notifyListeners();
  }

  Future<void> _loadEv() async {
    try {
      final stations = await _evApi.fetchStations();
      _evStations = stations;
      _isLoadingEv = false;
    } catch (e) {
      _isLoadingEv = false;
      _stationError ??= '전기 충전소 데이터를 불러오지 못했습니다.';
    }
    notifyListeners();
  }

  Future<void> _loadParking() async {
    try {
      final lots = await _parkingApi.fetchAll(size: 1000);
      _parkingLots = lots;
      _isLoadingParking = false;
    } catch (e) {
      _isLoadingParking = false;
      _stationError ??= '주차장 데이터를 불러오지 못했습니다.';
    }
    notifyListeners();
  }

  void toggleH2() {
    _showH2 = !_showH2;
    notifyListeners();
  }

  void toggleEv() {
    _showEv = !_showEv;
    notifyListeners();
  }

  void toggleParking() {
    _showParking = !_showParking;
    notifyListeners();
  }

  /// 현재 필터 상태에 맞춰 클러스터 가능한 마커 목록을 반환.
  Set<NClusterableMarker> buildMarkers({
    required NClusterableMarker Function(H2Station) h2Builder,
    required NClusterableMarker Function(EVStation) evBuilder,
    required NClusterableMarker Function(ParkingLot) parkingBuilder,
  }) {
    final overlays = <NClusterableMarker>{};
    if (_showH2) overlays.addAll(h2StationsWithCoords.map(h2Builder));
    if (_showEv) overlays.addAll(evStationsWithCoords.map(evBuilder));
    if (_showParking) overlays.addAll(parkingLotsWithCoords.map(parkingBuilder));
    return overlays;
  }

  /// nearbySearch 결과를 통째로 반영할 때 사용한다.
  void updateFromNearby({
    List<H2Station>? h2Stations,
    List<EVStation>? evStations,
    List<ParkingLot>? parkingLots,
  }) {
    if (h2Stations != null) {
      _h2Stations = h2Stations;
      _isLoadingH2 = false;
    }
    if (evStations != null) {
      _evStations = evStations;
      _isLoadingEv = false;
    }
    if (parkingLots != null) {
      _parkingLots = parkingLots;
      _isLoadingParking = false;
    }
    notifyListeners();
  }
}
