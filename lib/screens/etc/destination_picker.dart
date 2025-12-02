import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key, required this.initialTarget});

  final NLatLng initialTarget;

  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  NaverMapController? _controller;
  NMarker? _marker;
  NLatLng? _selected;
  String? _selectedName;

  final TextEditingController _queryController = TextEditingController();
  List<_SearchResult> _results = const [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('목적지 선택'),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(
                      DestinationPickResult(
                        position: _selected!,
                        name: _selectedName,
                      ),
                    ),
            child: const Text('확인'),
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: widget.initialTarget,
                zoom: 12,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _controller = controller;
            },
            onMapTapped: (point, latLng) => _setMarker(latLng, name: '선택한 위치'),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildSearchBox(),
          ),
          if (_searchError != null)
            Positioned(
              top: 70,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _searchError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          if (_isSearching)
            const Positioned(
              top: 80,
              left: 12,
              child: CircularProgressIndicator(),
            ),
          Positioned(
            top: 110,
            left: 12,
            right: 12,
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: _queryController,
        decoration: InputDecoration(
          hintText: '목적지 이름을 입력하세요',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _queryController.clear();
                _results = const [];
                _searchError = null;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_results.isEmpty) return const SizedBox.shrink();
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final item = _results[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade900,
              child: Text('${index + 1}'),
            ),
            title: Text(item.compactName),
            onTap: () {
              _focusTo(item.lat, item.lon);
              _setMarker(NLatLng(item.lat, item.lon), name: item.compactName);
              setState(() => _results = const []);
            },
          );
        },
      ),
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // 간단한 Nominatim 검색 (키 없이 사용 가능). 정책상 User-Agent를 지정한다.
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&limit=5&addressdetails=1&q=${Uri.encodeQueryComponent(query)}',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'e-lot-app/1.0'});
      if (res.statusCode != 200) {
        throw Exception('검색 실패 (${res.statusCode})');
      }
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      final parsed = data.map((e) => _SearchResult.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        _results = parsed;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = '검색에 실패했습니다. 다른 키워드를 입력하세요.';
        _isSearching = false;
      });
    }
  }

  Future<void> _focusTo(double lat, double lon) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.updateCamera(
      NCameraUpdate.fromCameraPosition(
        NCameraPosition(target: NLatLng(lat, lon), zoom: 14),
      ),
    );
  }

  Future<void> _setMarker(NLatLng position, {String? name}) async {
    final controller = _controller;
    setState(() {
      _selected = position;
      if (name != null) {
        _selectedName = name;
      } else {
        _selectedName ??= '선택한 위치';
      }
    });
    if (controller == null) return;

    _marker ??= NMarker(id: 'dest_marker', position: position);
    if (_marker != null) {
      await controller.addOverlay(_marker!);
      _marker!.setPosition(position);
    }
  }
}

class _SearchResult {
  _SearchResult({
    required this.displayName,
    required this.compactName,
    required this.lat,
    required this.lon,
  });

  final String displayName;
  final String compactName;
  final double lat;
  final double lon;

  factory _SearchResult.fromJson(Map<String, dynamic> json) {
    final fullName = (json['display_name'] ?? '').toString();
    return _SearchResult(
      displayName: fullName,
      compactName: _compactKoreanAddress(fullName),
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
    );
  }

  static String _compactKoreanAddress(String full) {
    final parts =
        full.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return full;

    final poi = parts.first; // 첫 번째는 장소명/POI
    String? country;
    String? city;
    String? district;
    String? postal;

    for (var i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      if (country == null && p.toLowerCase().contains('korea')) {
        country = '대한민국';
      } else if (city == null && (p.endsWith('시') || p.endsWith('도'))) {
        city = p;
      } else if (district == null &&
          (p.endsWith('구') || p.endsWith('군') || p.endsWith('시'))) {
        district = p;
      } else if (postal == null && RegExp(r'^\\d{5}$').hasMatch(p)) {
        postal = p; // 5자리 우편번호
      }
    }

    final ordered = [
      country ?? '대한민국',
      if (city != null) city,
      if (district != null) district,
      poi,
      if (postal != null) postal,
    ].whereType<String>();

    return ordered.join(' ');
  }
}

class DestinationPickResult {
  DestinationPickResult({required this.position, this.name});

  final NLatLng position;
  final String? name;
}
