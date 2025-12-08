class ParkingLot {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? totalSpaces;
  final int? availableSpaces;
  final int? occupiedSpaces;
  final String? tel;
  final String? feeInfo;
  final String? category;
  final String? type;
  final String? feeType;
  final bool? isFree;
  final int? baseTimeMinutes;
  final int? baseFee;
  final int? addTimeMinutes;
  final int? addFee;
  final int? dailyMaxFee;

  ParkingLot({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.totalSpaces,
    this.availableSpaces,
    this.occupiedSpaces,
    this.tel,
    this.feeInfo,
    this.category,
    this.type,
    this.feeType,
    this.isFree,
    this.baseTimeMinutes,
    this.baseFee,
    this.addTimeMinutes,
    this.addFee,
    this.dailyMaxFee,
  });

  factory ParkingLot.fromJson(Map<String, dynamic> json) {
    final location = _parseMap(json['location']);
    final stats =
        _parseMap(json['stats'] ?? json['availability'] ?? json['status']);
    final fee = _parseMap(json['fee'] ?? json['pricing']);

    final totalSpaces = _parseInt(
      json['totalSpaces'] ??
          json['capacity'] ??
          json['totalCount'] ??
          json['prkcmprt'] ??
          stats?['total'] ??
          stats?['capacity'] ??
          stats?['totalSpaces'],
    );
    final occupiedSpaces = _parseInt(
      json['occupiedSpaces'] ??
          json['currentParking'] ??
          json['curParking'] ??
          json['presentCar'] ??
          json['parkingCnt'] ??
          stats?['occupied'] ??
          stats?['using'],
    );
    final availableSpaces = _deriveAvailable(
      primary: _parseInt(
        json['availableSpaces'] ??
            json['remainCount'] ??
            json['available'] ??
            json['leftCnt'] ??
            stats?['available'] ??
            stats?['remain'] ??
            stats?['availableSpaces'],
      ),
      total: totalSpaces,
      occupied: occupiedSpaces,
    );

    return ParkingLot(
      id: _stringOrFallback(
        json['id'] ??
            json['parkingLotId'] ??
            json['lotId'] ??
            json['parkingId'] ??
            json['prkplceNo'],
        'unknown',
      ),
      name: _stringOrFallback(
        json['name'] ??
            json['parkingLotName'] ??
            json['title'] ??
            json['prkplceNm'],
        '주차장',
      ),
      address: _parseString(
        json['address'] ??
            json['roadAddress'] ??
            json['fullAddress'] ??
            json['rdnmadr'] ??
            json['lnmadr'] ??
            location?['address'],
      ),
      latitude: _parseDouble(
        json['latitude'] ??
            json['lat'] ??
            json['y'] ??
            location?['latitude'] ??
            location?['lat'] ??
            location?['y'],
      ),
      longitude: _parseDouble(
        json['longitude'] ??
            json['lng'] ??
            json['x'] ??
            location?['longitude'] ??
            location?['lng'] ??
            location?['x'],
      ),
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces,
      occupiedSpaces: occupiedSpaces,
      tel: _parseString(
        json['tel'] ??
            json['phone'] ??
            json['telNumber'] ??
            json['phoneNumber'] ??
            json['telno'] ??
            json['contact'],
      ),
      feeInfo: _parseString(
        json['feeInfo'] ??
            json['pricing'] ??
            json['priceInfo'] ??
            fee?['info'],
      ),
      category: _parseString(
        json['category'] ??
            json['parkingCategory'] ??
            json['prkplceSe'] ??
            json['classification'],
      ),
      type: _parseString(
        json['type'] ??
            json['parkingType'] ??
            json['prkplceTy'] ??
            json['facilityType'],
      ),
      feeType: _parseString(
        json['feeType'] ??
            json['parkingFeeType'] ??
            json['parkingchrgeInfo'] ??
            fee?['type'],
      ),
      isFree: _parseBool(
        json['free'] ??
            json['isFree'] ??
            json['parkingFree'] ??
            json['freeYn'] ??
            json['parkingFreeYn'] ??
            fee?['free'],
      ),
      baseTimeMinutes: _parseInt(
        json['baseTime'] ??
            json['basicTime'] ??
            json['timeRate'] ??
            json['basicTimeMinutes'] ??
            fee?['baseTime'] ??
            fee?['timeRate'],
      ),
      baseFee: _parseInt(
        json['baseFee'] ??
            json['basicFee'] ??
            json['basicCharge'] ??
            json['rates'] ??
            json['baseRate'] ??
            fee?['baseFee'] ??
            fee?['rates'],
      ),
      addTimeMinutes: _parseInt(
        json['addTime'] ??
            json['addTimeRates'] ??
            json['addUnitTime'] ??
            json['extraTime'] ??
            fee?['addTime'] ??
            fee?['addTimeRates'],
      ),
      addFee: _parseInt(
        json['addFee'] ??
            json['addRates'] ??
            json['addUnitCharge'] ??
            json['extraFee'] ??
            fee?['addFee'] ??
            fee?['addRates'],
      ),
      dailyMaxFee: _parseInt(
        json['dayMaxFee'] ??
            json['dayMaximum'] ??
            json['dailyMaxAmount'] ??
            json['maximumFee'] ??
            fee?['dayMaxFee'] ??
            fee?['dayMaximum'],
      ),
    );
  }

  /// 사람이 읽을 수 있는 요약 요금 정보.
  String? get feeSummary {
    if (feeInfo != null && feeInfo!.trim().isNotEmpty) {
      return feeInfo!.trim();
    }

    final parts = <String>[];
    final feeLabel = _normalizeFeeTypeLabel(feeType, isFree);
    if (feeLabel != null) {
      parts.add(feeLabel);
    }
    if (baseTimeMinutes != null && baseFee != null) {
      parts.add('기본 $baseTimeMinutes분 ${_formatCurrency(baseFee!)}');
    } else if (baseFee != null) {
      parts.add('기본 ${_formatCurrency(baseFee!)}');
    }
    if (addTimeMinutes != null && addFee != null) {
      parts.add('추가 $addTimeMinutes분 ${_formatCurrency(addFee!)}');
    } else if (addFee != null) {
      parts.add('추가 ${_formatCurrency(addFee!)}');
    }
    if (dailyMaxFee != null) {
      parts.add('일 최대 ${_formatCurrency(dailyMaxFee!)}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? get feeTypeLabel => _normalizeFeeTypeLabel(feeType, isFree);

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
      if (normalized == '무료') return true;
      if (normalized == '유료') return false;
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

  static Map<String, dynamic>? _parseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  static int? _deriveAvailable({
    required int? primary,
    required int? total,
    required int? occupied,
  }) {
    if (primary != null) return primary;
    if (total != null && occupied != null) {
      final remain = total - occupied;
      return remain < 0 ? 0 : remain;
    }
    return null;
  }

  static String? _normalizeFeeTypeLabel(String? raw, bool? isFree) {
    if (isFree == true) return '무료';
    if (isFree == false) return '유료';
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.contains('무료') || normalized == 'free' || normalized == 'y') {
      return '무료';
    }
    if (normalized.contains('유료') || normalized == 'paid' || normalized == 'n') {
      return '유료';
    }
    if (normalized == '0') return '무료';
    if (normalized == '1') return '유료';
    return raw?.trim();
  }

  static String _formatCurrency(int amount) {
    final raw = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(raw[i]);
    }
    return '${buffer.toString()}원';
  }
}
