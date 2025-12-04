class RouteRankingResponse {
  RouteRankingResponse({required this.route, required this.rankedStations});

  final RouteInfo? route;
  final List<RankedStation> rankedStations;

  factory RouteRankingResponse.fromJson(Map<String, dynamic> json) {
    final ranked = (json['rankedStations'] as List? ?? [])
        .map((e) => RankedStation.fromJson(e as Map<String, dynamic>))
        .toList();
    final routeJson = json['route'] as Map<String, dynamic>?;
    return RouteRankingResponse(
      route: routeJson == null ? null : RouteInfo.fromJson(routeJson),
      rankedStations: ranked,
    );
  }
}

class RouteInfo {
  RouteInfo({
    required this.start,
    required this.end,
    required this.distanceKm,
    required this.estimatedDurationMin,
  });

  final Point start;
  final Point end;
  final double? distanceKm;
  final double? estimatedDurationMin;

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      start: Point.fromJson(json['start'] as Map<String, dynamic>),
      end: Point.fromJson(json['end'] as Map<String, dynamic>),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      estimatedDurationMin: (json['estimatedDurationMin'] as num?)?.toDouble(),
    );
  }
}

class Point {
  Point({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class RankedStation {
  RankedStation({
    required this.rank,
    required this.score,
    required this.scoreBreakdown,
    required this.station,
  });

  final int rank;
  final double score;
  final ScoreBreakdown scoreBreakdown;
  final StationInfo station;

  factory RankedStation.fromJson(Map<String, dynamic> json) {
    return RankedStation(
      rank: json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      scoreBreakdown:
          ScoreBreakdown.fromJson(json['scoreBreakdown'] as Map<String, dynamic>),
      station: StationInfo.fromJson(json['station'] as Map<String, dynamic>),
    );
  }
}

class ScoreBreakdown {
  ScoreBreakdown({
    required this.routeProximity,
    required this.availability,
    required this.rating,
    required this.popularity,
    required this.price,
    required this.directionality,
  });

  final double routeProximity;
  final double availability;
  final double rating;
  final double popularity;
  final double price;
  final double directionality;

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    double toDouble(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    return ScoreBreakdown(
      routeProximity: toDouble('routeProximity'),
      availability: toDouble('availability'),
      rating: toDouble('rating'),
      popularity: toDouble('popularity'),
      price: toDouble('price'),
      directionality: toDouble('directionality'),
    );
  }
}

class StationInfo {
  StationInfo({
    required this.type,
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distanceFromRouteKm,
    required this.detourMinutes,
    required this.statistics,
  });

  final String type;
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final double? distanceFromRouteKm;
  final int? detourMinutes;
  final StatisticsInfo? statistics;

  factory StationInfo.fromJson(Map<String, dynamic> json) {
    return StationInfo(
      type: (json['type'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      distanceFromRouteKm: (json['distanceFromRouteKm'] as num?)?.toDouble(),
      detourMinutes: json['detourMinutes'] as int?,
      statistics: json['statistics'] == null
          ? null
          : StatisticsInfo.fromJson(json['statistics'] as Map<String, dynamic>),
    );
  }
}

class StatisticsInfo {
  StatisticsInfo({
    required this.averageRating,
    required this.totalReviews,
    required this.currentAvailability,
    required this.totalCapacity,
    required this.averagePrice,
  });

  final double? averageRating;
  final int totalReviews;
  final int currentAvailability;
  final int totalCapacity;
  final double? averagePrice;

  factory StatisticsInfo.fromJson(Map<String, dynamic> json) {
    return StatisticsInfo(
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      currentAvailability: (json['currentAvailability'] as num?)?.toInt() ?? 0,
      totalCapacity: (json['totalCapacity'] as num?)?.toInt() ?? 0,
      averagePrice: (json['averagePrice'] as num?)?.toDouble(),
    );
  }
}
