class ParkingLot {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? totalSpaces;
  final int? availableSpaces;
  final String? tel;
  final String? feeInfo;

  ParkingLot({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.totalSpaces,
    this.availableSpaces,
    this.tel,
    this.feeInfo,
  });

  factory ParkingLot.fromJson(Map<String, dynamic> json) {
    return ParkingLot(
      id: _stringOrFallback(
        json['id'] ?? json['parkingLotId'] ?? json['lotId'],
        'unknown',
      ),
      name: _stringOrFallback(
        json['name'] ?? json['parkingLotName'] ?? json['title'],
        '주차장',
      ),
      address: _parseString(json['address'] ?? json['roadAddress']),
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
      totalSpaces: _parseInt(json['totalSpaces'] ?? json['capacity']),
      availableSpaces:
          _parseInt(json['availableSpaces'] ?? json['remainCount']),
      tel: _parseString(json['tel'] ?? json['phone']),
      feeInfo: _parseString(json['feeInfo'] ?? json['pricing']),
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
}
