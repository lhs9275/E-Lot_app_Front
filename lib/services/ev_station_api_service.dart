// lib/services/h2_station_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ev_station.dart';

late final EVStationApiService evStationApi;

void configureEVStationApi({required String baseUrl}) {
  evStationApi = EVStationApiService(baseUrl: baseUrl);
}

class EVStationApiService {
  final String baseUrl;

  EVStationApiService({required this.baseUrl});

  Future<List<EVStation>> fetchStations() async {
    final url = _buildStationsUri();
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((e) => EVStation.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('충전소 정보를 불러오지 못했습니다: ${response.statusCode}');
    }
  }

  Uri _buildStationsUri() {
    final normalized =
    baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalized/mapi/ev/stations?type=all');
  }
}
