class Reservation {
  final String reservationCode;
  final String? reservationStatus;
  final String? reservationStatusLabel;
  final String? paymentStatus;
  final String? paymentStatusLabel;
  final int? totalAmount;
  final String? itemName;
  final DateTime? usedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Reservation({
    required this.reservationCode,
    this.reservationStatus,
    this.reservationStatusLabel,
    this.paymentStatus,
    this.paymentStatusLabel,
    this.totalAmount,
    this.itemName,
    this.usedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      reservationCode: _parseString(json['reservationCode']) ?? '',
      reservationStatus: _parseString(json['reservationStatus']),
      reservationStatusLabel: _parseString(json['reservationStatusLabel']),
      paymentStatus: _parseString(json['paymentStatus']),
      paymentStatusLabel: _parseString(json['paymentStatusLabel']),
      totalAmount: _parseInt(json['totalAmount']),
      itemName: _parseString(json['itemName']),
      usedAt: _parseDateTime(json['usedAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  bool get isPaid => reservationStatus == 'PAID';
  bool get isCancelled =>
      reservationStatus == 'CANCELLED' || paymentStatus == 'CANCELLED';
  bool get isFailed => paymentStatus == 'FAILED';
  bool get isPending =>
      reservationStatus == 'PAYMENT_PENDING' || paymentStatus == 'READY';

  bool get isFinalStatus =>
      reservationStatus == 'PAID' ||
      reservationStatus == 'USED' ||
      reservationStatus == 'EXPIRED' ||
      reservationStatus == 'CANCELLED' ||
      reservationStatus == 'REFUNDED';

  String? get targetType {
    final parts = reservationCode.split('-');
    if (parts.isEmpty) return null;
    final prefix = parts.first.trim();
    if (prefix.isEmpty) return null;
    return prefix;
  }

  String? get targetId {
    final parts = reservationCode.split('-');
    if (parts.length < 3) return null;
    final id = parts.sublist(1, parts.length - 1).join('-').trim();
    if (id.isEmpty) return null;
    return id;
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static String? _parseString(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      // assume epoch millis
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        return DateTime.parse(trimmed);
      } catch (_) {
        final asInt = int.tryParse(trimmed);
        if (asInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        }
        return null;
      }
    }
    return null;
  }
}
