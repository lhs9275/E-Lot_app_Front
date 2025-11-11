// lib/models/h2_station.dart

class H2Station {
  final String stationName;      // 충전소 이름
  final String statusName;       // 영업중 / 영업마감
  final int? waitingCount;       // 대기 차량 수 (nullable)
  final int? maxChargeCount;     // 최대 충전 가능 대수 (nullable)
  final String lastModifiedAt;   // 최종 갱신 시간 (String으로 일단 처리)

  H2Station({
    required this.stationName,
    required this.statusName,
    this.waitingCount,
    this.maxChargeCount,
    required this.lastModifiedAt,
  });

  factory H2Station.fromJson(Map<String, dynamic> json) {
    return H2Station(
      stationName: json['stationName'] as String,
      statusName: json['statusName'] as String,
      waitingCount: json['waitingCount'] as int?,     // Integer → int?
      maxChargeCount: json['maxChargeCount'] as int?, // Integer → int?
      lastModifiedAt: json['lastModifiedAt'] as String,
    );
  }
}