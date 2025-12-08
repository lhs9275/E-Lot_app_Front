class EVStation {
  final String stationId;
  final String stationName;
  final String status; // 예) 2
  final String statusLabel; // 예) 충전대기
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? addressDetail;
  final String? useTime;
  final int? outputKw;
  final String? statusUpdatedAt;
  final bool? parkingFree;
  final bool? limited;
  final String? limitDetail;
  final bool? deleted;
  final String? deleteDetail;
  final bool? trafficControl;
  final String? businessId;
  final String? businessName;
  final String? businessOperator;
  final String? businessCall;
  final String? kind;
  final String? kindDetail;
  final String? method;
  final String? powerType;
  final String? maker;
  final String? lastStartedAt;
  final String? lastEndedAt;
  final String? currentStartedAt;
  final String? commissioningYear;
  final String? floor;
  final String? floorType;
  final String? note;
  final String? location;
  final String? regionCode;
  final String? subRegionCode;
  final String? chargerId;
  final String? chargerType;
  final int? pricePerKwh; // 단가 (원/kWh)
  final String? priceText;

  EVStation({
    required this.stationId,
    required this.stationName,
    required this.status,
    required this.statusLabel,
    this.latitude,
    this.longitude,
    this.address,
    this.addressDetail,
    this.useTime,
    this.outputKw,
    this.statusUpdatedAt,
    this.parkingFree,
    this.limited,
    this.limitDetail,
    this.deleted,
    this.deleteDetail,
    this.trafficControl,
    this.businessId,
    this.businessName,
    this.businessOperator,
    this.businessCall,
    this.kind,
    this.kindDetail,
    this.method,
    this.powerType,
    this.maker,
    this.lastStartedAt,
    this.lastEndedAt,
    this.currentStartedAt,
    this.commissioningYear,
    this.floor,
    this.floorType,
    this.note,
    this.location,
    this.regionCode,
    this.subRegionCode,
    this.chargerId,
    this.chargerType,
    this.pricePerKwh,
    this.priceText,
  });

  factory EVStation.fromJson(Map<String, dynamic> json) {
    return EVStation(
      stationId: _stringOrFallback(json['stationId'], 'unknown'),
      stationName: _stringOrFallback(json['stationName'], '이름 미상'),
      status: _stringOrFallback(json['status'], '상태 정보 없음'),
      statusLabel: _stringOrFallback(json['statusLabel'], '상태 정보 없음'),
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
      address: _parseString(json['address']),
      addressDetail: _parseString(json['addressDetail']),
      useTime: _parseString(json['useTime']),
      outputKw: _parseInt(json['outputKw']),
      statusUpdatedAt: _parseString(json['statusUpdatedAt']),
      parkingFree: _parseBool(json['parkingFree']),
      limited: _parseBool(json['limited']),
      limitDetail: _parseString(json['limitDetail']),
      deleted: _parseBool(json['deleted']),
      deleteDetail: _parseString(json['deleteDetail']),
      trafficControl: _parseBool(json['trafficControl']),
      businessId: _parseString(json['businessId']),
      businessName: _parseString(json['businessName']),
      businessOperator: _parseString(json['businessOperator']),
      businessCall: _parseString(json['businessCall']),
      kind: _parseString(json['kind']),
      kindDetail: _parseString(json['kindDetail']),
      method: _parseString(json['method']),
      powerType: _parseString(json['powerType']),
      maker: _parseString(json['maker']),
      lastStartedAt: _parseString(json['lastStartedAt']),
      lastEndedAt: _parseString(json['lastEndedAt']),
      currentStartedAt: _parseString(json['currentStartedAt']),
      commissioningYear: _parseString(json['commissioningYear']),
      floor: _parseString(json['floor']),
      floorType: _parseString(json['floorType']),
      note: _parseString(json['note']),
      location: _parseString(json['location']),
      regionCode: _parseString(json['regionCode']),
      subRegionCode: _parseString(json['subRegionCode']),
      chargerId: _parseString(json['chargerId']),
      chargerType: _parseString(json['chargerType']),
      pricePerKwh: _parseInt(
        json['price'] ??
            json['pricePerKwh'] ??
            json['unitPrice'] ??
            json['fee'] ??
            json['chargingPrice'] ??
            json['kwhPrice'],
      ),
      priceText: _parseString(
        json['priceText'] ??
            json['price_text'] ??
            json['priceDesc'] ??
            json['price_desc'] ??
            json['feeInfo'],
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

  static bool? _parseBool(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }
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

  String? get priceLabel {
    if (priceText != null && priceText!.trim().isNotEmpty) {
      return priceText!.trim();
    }
    if (pricePerKwh != null) {
      return '${_formatCurrency(pricePerKwh!)} / kWh';
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
