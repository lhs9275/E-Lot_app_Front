import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../models/ev_station.dart';
import '../../models/h2_station.dart';
import '../../models/parking_lot.dart';

final NOverlayImage _h2MarkerIcon =
    NOverlayImage.fromAssetImage('lib/assets/icons/markers/h2_pin.png');
final NOverlayImage _evMarkerIcon =
    NOverlayImage.fromAssetImage('lib/assets/icons/markers/ev_pin.png');
final NOverlayImage _parkingMarkerIcon =
    NOverlayImage.fromAssetImage('lib/assets/icons/markers/parking_pin.png');

NMarker buildH2Marker({
  required H2Station station,
  required Color tint,
  required Color Function(String status) statusColor,
  required void Function(H2Station station) onTap,
}) {
  final lat = station.latitude!;
  final lng = station.longitude!;
  final marker = NMarker(
    id: 'h2_marker_${station.stationId}_$lat$lng',
    position: NLatLng(lat, lng),
    caption: NOverlayCaption(
      text: '[H2] ${station.stationName}',
      textSize: 12,
      color: Colors.black,
      haloColor: Colors.white,
    ),
    subCaption: NOverlayCaption(
      text: station.statusName,
      textSize: 11,
      color: statusColor(station.statusName),
      haloColor: Colors.white,
    ),
    icon: _h2MarkerIcon,
    size: const Size(64, 64),
    //iconTintColor: tint,
  );

  marker.setOnTapListener((_) => onTap(station));
  return marker;
}

NMarker buildEvMarker({
  required EVStation station,
  required Color tint,
  required Color Function(String status) statusColor,
  required void Function(EVStation station) onTap,
}) {
  final lat = station.latitude!;
  final lng = station.longitude!;
  final marker = NMarker(
    id: 'ev_marker_${station.stationId}_$lat$lng',
    position: NLatLng(lat, lng),
    caption: NOverlayCaption(
      text: '[EV] ${station.stationName}',
      textSize: 12,
      color: Colors.black,
      haloColor: Colors.white,
    ),
    subCaption: NOverlayCaption(
      text: station.statusLabel,
      textSize: 11,
      color: statusColor(station.statusLabel),
      haloColor: Colors.white,
    ),

    icon: _evMarkerIcon,
    size: const Size(64, 64),
    //iconTintColor: tint,
  );

  marker.setOnTapListener((_) => onTap(station));
  return marker;
}

NMarker buildParkingMarker({
  required ParkingLot lot,
  required Color tint,
  required void Function(ParkingLot lot) onTap,
}) {
  final lat = lot.latitude!;
  final lng = lot.longitude!;
  final marker = NMarker(
    id: 'parking_marker_${lot.id}_$lat$lng',
    position: NLatLng(lat, lng),
    caption: NOverlayCaption(
      text: '[P] ${lot.name}',
      textSize: 12,
      color: Colors.black,
      haloColor: Colors.white,
    ),
    subCaption: NOverlayCaption(
      text: lot.availableSpaces != null && lot.totalSpaces != null
          ? '잔여 ${lot.availableSpaces}/${lot.totalSpaces}'
          : (lot.availableSpaces != null
              ? '잔여 ${lot.availableSpaces}'
              : '주차장'),
      textSize: 11,
      color: Colors.deepOrange,
      haloColor: Colors.white,
    ),

    icon: _parkingMarkerIcon,
    size: const Size(64, 64),
    //iconTintColor: tint,
  );

  marker.setOnTapListener((_) => onTap(lot));
  return marker;
}
