// lib/screens/h2info_screen.dart

import 'package:flutter/material.dart';
import '../models/h2_station.dart';
import '../services/h2_station_api_service.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late Future<List<H2Station>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = h2StationApi.fetchStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('수소 충전소 정보'),
      ),
      body: FutureBuilder<List<H2Station>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          // 로딩
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 에러
          if (snapshot.hasError) {
            return Center(
              child: Text('에러 발생: ${snapshot.error}'),
            );
          }

          // 데이터 없음
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('표시할 충전소 정보가 없습니다.'),
            );
          }

          final stations = snapshot.data!;

          return ListView.builder(
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(station.stationName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('상태: ${station.statusName}'),
                      Text('대기 차량: ${station.waitingCount ?? 0}대'),
                      Text('최대 충전 가능: ${station.maxChargeCount ?? 0}대'),
                      Text('최종 갱신: ${station.lastModifiedAt}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}