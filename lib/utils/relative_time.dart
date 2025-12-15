DateTime? parseBackendDateTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (RegExp(r'^\d{14}$').hasMatch(trimmed)) {
    final year = int.tryParse(trimmed.substring(0, 4));
    final month = int.tryParse(trimmed.substring(4, 6));
    final day = int.tryParse(trimmed.substring(6, 8));
    final hour = int.tryParse(trimmed.substring(8, 10));
    final minute = int.tryParse(trimmed.substring(10, 12));
    final second = int.tryParse(trimmed.substring(12, 14));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }
    if (year < 2000 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        second < 0 ||
        second > 59) {
      return null;
    }
    final parsed = DateTime(year, month, day, hour, minute, second);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute ||
        parsed.second != second) {
      return null;
    }
    return parsed;
  }

  if (RegExp(r'^\d{12}$').hasMatch(trimmed)) {
    final year = int.tryParse(trimmed.substring(0, 4));
    final month = int.tryParse(trimmed.substring(4, 6));
    final day = int.tryParse(trimmed.substring(6, 8));
    final hour = int.tryParse(trimmed.substring(8, 10));
    final minute = int.tryParse(trimmed.substring(10, 12));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    if (year < 2000 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    final parsed = DateTime(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      return null;
    }
    return parsed;
  }

  if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
    final year = int.tryParse(trimmed.substring(0, 4));
    final month = int.tryParse(trimmed.substring(4, 6));
    final day = int.tryParse(trimmed.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  final numeric = int.tryParse(trimmed);
  if (numeric != null) {
    if (numeric == 0) return null;
    if (trimmed.length <= 10) {
      if (numeric < 946684800) return null; // 2000-01-01 (epoch seconds)
      return DateTime.fromMillisecondsSinceEpoch(
        numeric * 1000,
        isUtc: true,
      ).toLocal();
    }

    if (trimmed.length == 13) {
      if (numeric < 946684800000) return null; // 2000-01-01 (epoch millis)
      return DateTime.fromMillisecondsSinceEpoch(
        numeric,
        isUtc: true,
      ).toLocal();
    }

    if (trimmed.length >= 15) {
      if (numeric < 946684800000000) return null; // 2000-01-01 (epoch micros)
      return DateTime.fromMicrosecondsSinceEpoch(
        numeric,
        isUtc: true,
      ).toLocal();
    }

    return null;
  }

  var normalized = trimmed;
  if (!normalized.contains('T') && normalized.contains(' ')) {
    normalized = normalized.replaceFirst(' ', 'T');
  }

  final longFractionMatch =
      RegExp(r'^(.*\.)(\d{7,})(Z|[+-]\d{2}:?\d{2})?$').firstMatch(normalized);
  if (longFractionMatch != null) {
    final prefix = longFractionMatch.group(1)!;
    final fraction = longFractionMatch.group(2)!;
    final suffix = longFractionMatch.group(3) ?? '';
    normalized = '$prefix${fraction.substring(0, 6)}$suffix';
  }

  final tzNoColonMatch = RegExp(r'([+-]\d{2})(\d{2})$').firstMatch(normalized);
  if (tzNoColonMatch != null) {
    normalized =
        '${normalized.substring(0, tzNoColonMatch.start)}${tzNoColonMatch.group(1)}:${tzNoColonMatch.group(2)}';
  }

  try {
    final parsed = DateTime.parse(normalized);
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    if (local.year < 2000) return null;
    return local;
  } catch (_) {
    return null;
  }
}

String formatKoreanTimeAgo(
  DateTime dateTime, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  var diff = reference.difference(dateTime);
  if (diff.isNegative) diff = Duration.zero;

  if (diff.inSeconds < 60) {
    final seconds = diff.inSeconds <= 0 ? 1 : diff.inSeconds;
    return '$seconds초전';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}분전';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}시간전';
  }
  if (diff.inDays == 1) {
    return '하루전';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays}일전';
  }
  final months = (diff.inDays / 30).floor();
  if (months < 12) {
    return '${months <= 0 ? 1 : months}개월전';
  }
  final years = (diff.inDays / 365).floor();
  return '${years <= 0 ? 1 : years}년전';
}

String formatKoreanRelativeTime(
  String? raw, {
  DateTime? now,
  String unknownLabel = '정보 없음',
}) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return unknownLabel;
  if (trimmed == '0') return unknownLabel;
  if (trimmed.startsWith('1970-01-01')) return unknownLabel;

  final parsed = parseBackendDateTime(raw);
  if (parsed == null) {
    return unknownLabel;
  }
  return formatKoreanTimeAgo(parsed, now: now);
}
