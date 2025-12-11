import '../../models/ev_station.dart';
import '../../models/h2_station.dart';
import '../../models/parking_lot.dart';

enum MapPointType { h2, ev, parking }

/// 공통 마커/클러스터링용 좌표 래퍼.
class MapPoint {
  MapPoint.h2(H2Station station)
      : id = 'h2_${station.stationId}',
        lat = station.latitude!,
        lng = station.longitude!,
        type = MapPointType.h2,
        h2 = station,
        ev = null,
        parking = null;

  MapPoint.ev(EVStation station)
      : id = 'ev_${station.stationId}',
        lat = station.latitude!,
        lng = station.longitude!,
        type = MapPointType.ev,
        h2 = null,
        ev = station,
        parking = null;

  MapPoint.parking(ParkingLot lot)
      : id = 'parking_${lot.id}',
        lat = lot.latitude!,
        lng = lot.longitude!,
        type = MapPointType.parking,
        h2 = null,
        ev = null,
        parking = lot;

  final String id;
  final double lat;
  final double lng;
  final MapPointType type;
  final H2Station? h2;
  final EVStation? ev;
  final ParkingLot? parking;
}
