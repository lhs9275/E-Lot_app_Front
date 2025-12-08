// lib/models/h2_station.dart
class H2Station {
  final String stationId;      // ⭐ 즐겨찾기/백엔드용 고유 ID
  final String stationName;    // 충전소 이름
  final String statusName;     // 영업중 / 영업마감
  final int? waitingCount;     // 대기 차량 수 (nullable)
  final int? maxChargeCount;   // 최대 충전 가능 대수 (nullable)
  final String? lastModifiedAt; // 최종 갱신 시간
  final int? price;            // 단가 (원/kg)
  final String? priceText;     // 가공된 단가 문자열이 있으면 사용
  final double? latitude;      // 위도
  final double? longitude;     // 경도

  H2Station({
    required this.stationId,
    required this.stationName,
    required this.statusName,
    this.waitingCount,
    this.maxChargeCount,
    this.lastModifiedAt,
    this.price,
    this.priceText,
    this.latitude,
    this.longitude,
  });

  factory H2Station.fromJson(Map<String, dynamic> json) {
    final realtime = _parseMap(json['realtime']);
    final operation = _parseMap(json['operation']);

    return H2Station(

      // 🔥 백엔드/H2 응답에서 필드명이 stationId라고 했으니까 그대로 사용
      stationId: _stringOrFallback(json['stationId'], 'UNKNOWN_ID'),

      stationName: _stringOrFallback(
        json['stationName'],
        '이름 미상',
      ),
      statusName: _stringOrFallback(
        realtime?['statusName'] ?? json['statusName'],
        '상태 정보 없음',
      ),
      waitingCount: _parseInt(
        realtime?['waitingCount'] ?? json['waitingCount'],
      ),
      maxChargeCount: _parseInt(
        realtime?['maxChargeCount'] ?? json['maxChargeCount'],
      ),
      lastModifiedAt: _parseString(
        realtime?['lastModifiedAt'] ?? json['lastModifiedAt'],
      ),
      price: _parseInt(
        realtime?['price'] ??
            operation?['price'] ??
            json['price'] ??
            json['pricePerKg'] ??
            json['price_per_kg'] ??
            json['unitPrice'],
      ),
      priceText: _parseString(
        realtime?['priceText'] ??
            json['priceText'] ??
            json['price_text'] ??
            json['priceDesc'] ??
            json['price_desc'],
      ),
      latitude: _parseDouble(
        operation?['latitude'] ?? json['latitude'] ?? json['lat'],
      ),
      longitude: _parseDouble(
        operation?['longitude'] ?? json['longitude'] ?? json['lng'],
      ),
    );
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static double? _parseDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static String? _parseString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.trim().isEmpty) return null;
    return raw.toString();
  }

  static String _stringOrFallback(dynamic raw, String fallback) {
    final parsed = _parseString(raw);
    if (parsed == null || parsed.isEmpty) return fallback;
    return parsed;
  }

  static Map<String, dynamic>? _parseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  String? get priceLabel {
    if (priceText != null && priceText!.trim().isNotEmpty) {
      return priceText!.trim();
    }
    if (price != null) {
      return '${_formatCurrency(price!)} / kg';
    }
    return null;
  }

  static String _formatCurrency(int amount) {
    final raw = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return '${buffer.toString()}원';
  }
}
