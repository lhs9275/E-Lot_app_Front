import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalReport {
  LocalReport({
    required this.stationName,
    required this.reporterName,
    required this.reasonCode,
    required this.reasonLabel,
    required this.description,
    required this.timestampMs,
  });

  final String stationName;
  final String reporterName;
  final String reasonCode;
  final String reasonLabel;
  final String description;
  final int timestampMs;

  Map<String, dynamic> toJson() => {
        'stationName': stationName,
        'reporterName': reporterName,
        'reasonCode': reasonCode,
        'reasonLabel': reasonLabel,
        'description': description,
        'timestampMs': timestampMs,
      };

  factory LocalReport.fromJson(Map<String, dynamic> json) => LocalReport(
        stationName: (json['stationName'] ?? '') as String,
        reporterName: (json['reporterName'] ?? '') as String,
        reasonCode: (json['reasonCode'] ?? '') as String,
        reasonLabel: (json['reasonLabel'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        timestampMs: (json['timestampMs'] ?? 0) as int,
      );
}

class ReportHistoryStorage {
  static const _key = 'report_history';

  static Future<List<LocalReport>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    return raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .map(LocalReport.fromJson)
        .toList();
  }

  static Future<void> add(LocalReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.add(jsonEncode(report.toJson()));
    await prefs.setStringList(_key, list);
  }

  static Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await prefs.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
