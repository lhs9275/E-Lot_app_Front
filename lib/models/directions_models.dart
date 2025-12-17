import 'package:flutter_naver_map/flutter_naver_map.dart';

class DirectionsResult {
  const DirectionsResult({
    required this.path,
    this.distanceMeters,
    this.duration,
    this.option,
    this.raw,
  });

  final int? distanceMeters;
  final int? duration;
  final String? option;
  final List<NLatLng> path;
  final Map<String, dynamic>? raw;

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    return DirectionsResult(
      distanceMeters: _toInt(json['distance']),
      duration: _toInt(json['duration']),
      option: json['option']?.toString(),
      path: _parsePath(json['path']),
      raw: json['raw'] is Map<String, dynamic>
          ? json['raw'] as Map<String, dynamic>
          : null,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<NLatLng> _parsePath(dynamic value) {
    if (value is! List) return const <NLatLng>[];

    final points = <NLatLng>[];
    for (final element in value) {
      if (element is Map) {
        final map = element.cast<String, dynamic>();
        final lat = _toDouble(map['lat'] ?? map['latitude'] ?? map['y']);
        final lng =
            _toDouble(map['lng'] ?? map['lon'] ?? map['longitude'] ?? map['x']);
        if (lat == null || lng == null) continue;
        points.add(NLatLng(lat, lng));
        continue;
      }

      if (element is List && element.length >= 2) {
        final first = _toDouble(element[0]);
        final second = _toDouble(element[1]);
        if (first == null || second == null) continue;

        final firstLooksLng = first.abs() > 90 && first.abs() <= 180;
        final secondLooksLng = second.abs() > 90 && second.abs() <= 180;

        if (firstLooksLng && !secondLooksLng) {
          points.add(NLatLng(second, first)); // [lng,lat]
          continue;
        }
        if (secondLooksLng && !firstLooksLng) {
          points.add(NLatLng(first, second)); // [lat,lng]
          continue;
        }

        points.add(NLatLng(second, first)); // ambiguous -> assume [lng,lat]
      }
    }

    return points;
  }
}

