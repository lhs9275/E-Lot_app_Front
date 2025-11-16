import 'package:flutter/material.dart';
import '../models/ev_station.dart';
import '../services/ev_station_api_service.dart';

class EvInfoScreen extends StatefulWidget {
  const EvInfoScreen({super.key});

  @override
  State<EvInfoScreen> createState() => _EvInfoScreenState();
}

class _EvInfoScreenState extends State<EvInfoScreen> {
  late Future<List<EVStation>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = evStationApi.fetchStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전기 충전소 정보'),
      ),
      body: FutureBuilder<List<EVStation>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('에러 발생: ${snapshot.error}'),
            );
          }

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
                      Text('상태: ${station.statusLabel} (${station.status})'),
                      Text('출력: ${station.outputKw ?? 0} kW'),
                      Text('최근 갱신: ${station.statusUpdatedAt ?? '정보 없음'}'),
                      Text(
                        '주소: ${station.address ?? ''} ${station.addressDetail ?? ''}',
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '층: ${station.floor ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '무료주차: ${station.parkingFree == true ? 'Y' : 'N'}',
                        style: const TextStyle(fontSize: 12),
                      ),
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
