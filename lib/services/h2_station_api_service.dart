// lib/services/h2_station_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/h2_station.dart';

late final H2StationApiService h2StationApi;

void configureH2StationApi({required String baseUrl}) {
  h2StationApi = H2StationApiService(baseUrl: baseUrl);
}

class H2StationApiService {
  final String baseUrl;

  H2StationApiService({required this.baseUrl});

  Future<List<H2Station>> fetchStations() async {
    final url = Uri.parse('https://clos21.kr/mapi/h2/stations');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((e) => H2Station.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('충전소 정보를 불러오지 못했습니다: ${response.statusCode}');
    }
  }
}
