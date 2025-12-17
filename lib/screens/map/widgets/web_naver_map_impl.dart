// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../map_point.dart';

class WebNaverMap extends StatefulWidget {
  const WebNaverMap({
    super.key,
    required this.clientId,
    required this.latitude,
    required this.longitude,
    this.zoom = 12,
    this.points = const [],
  });

  final String clientId;
  final double latitude;
  final double longitude;
  final double zoom;
  final List<MapPoint> points;

  @override
  State<WebNaverMap> createState() => _WebNaverMapState();
}

class _WebNaverMapState extends State<WebNaverMap> {
  static int _viewIdSeed = 0;
  late final String _viewId;
  html.DivElement? _element;
  Object? _map;
  String? _error;
  Object? _clusterer;
  List<Object> _markers = [];

  @override
  void initState() {
    super.initState();
    _viewId = 'naver-map-view-${_viewIdSeed++}';
    _element = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%';

    // 등록
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) => _element!);

    unawaited(_initMap());
  }

  Future<void> _initMap() async {
    try {
      await _loadScriptIfNeeded(widget.clientId);
      final naver = js_util.getProperty(js_util.globalThis, 'naver');
      final maps = js_util.getProperty(naver, 'maps');
      final mapOptions = js_util.jsify({
        'center': js_util.callConstructor(
          js_util.getProperty(maps, 'LatLng'),
          [widget.latitude, widget.longitude],
        ),
        'zoom': widget.zoom,
      });
      _map = js_util.callConstructor(
        js_util.getProperty(maps, 'Map'),
        [_element, mapOptions],
      );
      _syncMarkers();
      setState(() {});
    } catch (e) {
      setState(() {
        _error = '네이버 지도 초기화 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 포인트 업데이트 시 클러스터/마커 갱신
    if (_map != null) {
      _syncMarkers();
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_map == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return HtmlElementView(viewType: _viewId);
  }

  void _syncMarkers() {
    if (_map == null) return;

    // 기존 클러스터/마커 제거
    if (_clusterer != null) {
      js_util.callMethod(_clusterer!, 'setMap', [null]);
      _clusterer = null;
    }
    for (final m in _markers) {
      js_util.callMethod(m, 'setMap', [null]);
    }
    _markers = [];

    final naver = js_util.getProperty(js_util.globalThis, 'naver');
    final maps = js_util.getProperty(naver, 'maps');

    final markers = <Object>[];
    for (final p in widget.points) {
      final pos = js_util.callConstructor(
        js_util.getProperty(maps, 'LatLng'),
        [p.lat, p.lng],
      );
      final marker = js_util.callConstructor(
        js_util.getProperty(maps, 'Marker'),
        [
          js_util.jsify({
            'position': pos,
            'map': null,
          }),
        ],
      );
      markers.add(marker);
    }

    final clustererCtor = js_util.getProperty(maps, 'MarkerClustering');
    if (clustererCtor != null && clustererCtor is! Null) {
      _clusterer = js_util.callConstructor(clustererCtor, [
        js_util.jsify({
          'map': _map,
          'markers': markers,
          'disableClickZoom': false,
          'minClusterSize': 2,
          'maxZoom': 16,
        }),
      ]);
    } else {
      // clusterer가 없으면 기본 마커만 추가
      for (final m in markers) {
        js_util.callMethod(m, 'setMap', [_map]);
      }
    }

    _markers = markers;
  }
}

Future<void> _loadScriptIfNeeded(String clientId) {
  const scriptId = 'naver-maps-sdk';
  final completer = Completer<void>();

  final existing = html.document.getElementById(scriptId);
  if (existing != null) {
    // 이미 로드 시 바로 완료
    completer.complete();
    return completer.future;
  }

  final script = html.ScriptElement()
    ..id = scriptId
    ..type = 'text/javascript'
    ..src =
        'https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=$clientId&submodules=markerclustering';
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError('네이버 맵 JS 로드 실패');
    }
  });
  script.onLoad.listen((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  html.document.head?.append(script);
  return completer.future;
}
