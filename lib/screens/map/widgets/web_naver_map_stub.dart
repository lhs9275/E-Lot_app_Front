import 'package:flutter/material.dart';

import '../map_point.dart';

class WebNaverMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text('웹 지도는 현재 지원되지 않습니다.'),
    );
  }
}
