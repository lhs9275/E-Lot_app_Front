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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추천 랭킹'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildForm(),
              const SizedBox(height: 16),
              _buildRouteInfo(),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(child: Text(_error!))
              else if (_results.isEmpty)
                const Center(child: Text('랭킹 결과가 없습니다.'))
              else
                _buildResultList(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '경로 기반 추천',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              '출발지는 현재 위치로 자동 설정, 목적지는 지도 검색으로 선택하세요.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _buildLocationRow(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.radar, size: 16, color: Colors.indigo),
                          const SizedBox(width: 6),
                          Text('반경: ${_radiusKm.toStringAsFixed(1)} km'),
                        ],
                      ),
                      Slider(
                        activeColor: Colors.indigo,
                        value: _radiusKm,
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '${_radiusKm.toStringAsFixed(1)} km',
                        onChanged: (v) => setState(() => _radiusKm = v),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text('개수', style: TextStyle(fontWeight: FontWeight.w600)),
                    DropdownButton<int>(
                      value: _limit,
                      items: const [5, 10, 15, 20]
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (v) => setState(() => _limit = v ?? 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildToggleChip('EV', _includeEv, (v) => setState(() => _includeEv = v)),
                _buildToggleChip('H2', _includeH2, (v) => setState(() => _includeH2 = v)),
                _buildToggleChip('주차', _includeParking,
                    (v) => setState(() => _includeParking = v)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _loading ? null : _fetchRanking,
                child: const Text('추천 받기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => onChanged(v),
      selectedColor: Colors.indigo.shade100,
      checkmarkColor: Colors.indigo,
      labelStyle: TextStyle(
        color: selected ? Colors.indigo.shade900 : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: StadiumBorder(side: BorderSide(color: Colors.indigo.shade200)),
    );
  }

  Widget _buildLocationRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('출발 (현재 위치)'),
                subtitle: Text(_startLat == null ? '가져오는 중...' : _startLabel),
              ),
            ),
            TextButton(
              onPressed: _initLocation,
              child: const Text('위치 새로고침'),
            ),
          ],
        ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('도착'),
                subtitle: Text(
                  _endLabel ?? '지도에서 목적지를 선택하세요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _pickDestination,
              child: const Text('지도에서 선택'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteInfo() {
    final route = _routeInfo;
    if (route == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('경로 요약',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '거리: ${route.distanceKm?.toStringAsFixed(1) ?? '-'} km · '
                  '예상: ${route.estimatedDurationMin?.toStringAsFixed(0) ?? '-'} 분',
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.builder(
      itemCount: _results.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = _results[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _typeColor(item.station.type),
                      child: Text(
                        item.rank.toString(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.station.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.station.type} · 점수 ${item.score.toStringAsFixed(2)} · '
                            '이탈 ${item.station.distanceFromRouteKm?.toStringAsFixed(2) ?? '-'} km',
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (item.station.detourMinutes != null)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '우회 ${item.station.detourMinutes}분',
                          style: const TextStyle(
                              color: Colors.indigo, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildScoreChips(item.scoreBreakdown),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreChips(ScoreBreakdown sb) {
    Widget chip(String label, double value, Color color) {
      return Chip(
        label: Text('$label ${value.toStringAsFixed(2)}'),
        backgroundColor: color.withOpacity(0.1),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        chip('평점', sb.rating, Colors.orange),
        chip('가격', sb.price, Colors.teal),
      ],
    );
  }

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'EV':
        return Colors.green;
      case 'H2':
        return Colors.blue;
      case 'PARKING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
