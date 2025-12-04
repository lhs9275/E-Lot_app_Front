import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 클러스터 옵션과 빌더를 한 곳에서 관리해, iOS/Android 동작 차이를 줄인다.
NaverMapClusteringOptions buildClusterOptions({
  required NOverlayImage? clusterIcon,
  required Color fallbackTint,
}) {
  return NaverMapClusteringOptions(
    mergeStrategy: const NClusterMergeStrategy(
      willMergedScreenDistance: {
        NaverMapClusteringOptions.defaultClusteringZoomRange: 70.0,
      },
      maxMergeableScreenDistance: 90.0,
    ),
    clusterMarkerBuilder: (info, marker) {
      marker
        ..setIsFlat(true)
        ..setCaption(NOverlayCaption(
          text: info.size.toString(),
          textSize: 13,
          color: Colors.white,
          haloColor: Colors.transparent,
        ))
        ..setCaptionAligns(const [NAlign.center]);

      if (clusterIcon != null) {
        marker.setIcon(clusterIcon);
      } else {
        marker.setIconTintColor(fallbackTint);
      }
    },
  );
}
