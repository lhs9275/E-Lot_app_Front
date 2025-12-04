import NMapsMap

internal class ClusteringController: NMCDefaultClusterMarkerUpdater, NMCThresholdStrategy, NMCTagMergeStrategy, NMCMarkerManager {
    private let naverMapView: NMFMapView!
    private let overlayController: OverlayHandler
    private let messageSender: (_ method: String, _ args: Any) -> Void
    
    init(naverMapView: NMFMapView!, overlayController: OverlayHandler, messageSender: @escaping (_: String, _: Any) -> Void) {
        self.naverMapView = naverMapView
        self.overlayController = overlayController
        self.messageSender = messageSender
    }
    
    private var clusterOptions: NaverMapClusterOptions!
    
    private var clusterer: NMCClusterer<NClusterableMarkerInfo>?
    
    private var clusterableMarkers: [NClusterableMarkerInfo: NClusterableMarker] = [:]
    private var mergedScreenDistanceCacheArray: [Double] = Array(repeating: NMC_DEFAULT_SCREEN_DISTANCE, count: 24) // idx: zoom, distance
    private lazy var clusterMarkerUpdate = ClusterMarkerUpdater(callback: { [weak self] info, marker in
        self?.onClusterMarkerUpdate(info, marker)
    })
    private lazy var clusterableMarkerUpdate = ClusterableMarkerUpdater(callback: { [weak self] info, marker in
        self?.onClusterableMarkerUpdate(info, marker)
    })

    /// iOS에서 간헐적으로 클러스터 옵션이 세팅되기 전에 마커가 추가되면
    /// clusterer가 nil 상태로 남아 클러스터링이 동작하지 않는 경우가 있었다.
    /// 방어적으로 기본 옵션을 한 번 적용해 clusterer를 항상 초기화한다.
    private func ensureClustererInitialized() {
        if clusterer != nil { return }

        let fallbackOptions = NaverMapClusterOptions(
            enableZoomRange: NRange(min: 0, max: 21, includeMin: true, includeMax: true),
            animationDuration: 300,
            mergeStrategy: NClusterMergeStrategy(
                willMergedScreenDistance: [:],
                maxMergeableScreenDistance: NMC_DEFAULT_SCREEN_DISTANCE
            )
        )
        updateClusterOptions(clusterOptions ?? fallbackOptions)
    }
    
    func updateClusterOptions(_ options: NaverMapClusterOptions) {
        clusterOptions = options
        print(options)
        if clusterer != nil { clusterer?.mapView = nil }
        
        cacheScreenDistance(options.mergeStrategy.willMergedScreenDistance)
        
        let builder = NMCComplexBuilder<NClusterableMarkerInfo>()
        builder.minClusteringZoom = options.enableZoomRange.min ?? Int(NMF_MIN_ZOOM)
        builder.maxClusteringZoom = options.enableZoomRange.max ?? Int(NMF_MAX_ZOOM)
        builder.maxScreenDistance = options.mergeStrategy.maxMergeableScreenDistance
        builder.animationDuration = Double(options.animationDuration) * 0.001
        builder.thresholdStrategy = self
        builder.tagMergeStrategy = self
        builder.minIndexingZoom = 0
        builder.maxIndexingZoom = 0
        builder.markerManager = self
        builder.clusterMarkerUpdater = clusterMarkerUpdate
        builder.leafMarkerUpdater = clusterableMarkerUpdate
        let newClusterer = builder.build()
        newClusterer.addAll(clusterableMarkers)
        newClusterer.mapView = naverMapView
        clusterer = newClusterer
    }
    
    private func cacheScreenDistance(_ willMergedScreenDistance: Dictionary<NRange<Int>, Double>) {
        for i in Int(NMF_MIN_ZOOM)...Int(NMF_MAX_ZOOM) { // 0 ~ 21
            let firstMatchedDistance: Double? = willMergedScreenDistance.first(
                where: { k, v in k.isInRange(i) })?.value
            if let distance = firstMatchedDistance { mergedScreenDistanceCacheArray[i] = distance }
        }
    }
    
    private func updateClusterer() {
        clusterer!.mapView = nil
        clusterer!.mapView = naverMapView
    }
    
    func addClusterableMarkerAll(_ markers: [NClusterableMarker]) {
        ensureClustererInitialized()
        let markersWithTag: [NClusterableMarkerInfo: NClusterableMarker]
        = Dictionary(uniqueKeysWithValues: markers.map { ($0.clusterInfo, $0) })
        clusterer?.addAll(markersWithTag)
        clusterableMarkers.merge(markersWithTag, uniquingKeysWith: { $1 })
        updateClusterer()
    }
    
    func deleteClusterableMarker(_ overlayInfo: NOverlayInfo) {
        let clusterableOverlayInfo = NClusterableMarkerInfo(id: overlayInfo.id, tags: [:], position: NMGLatLng.invalid())
        clusterableMarkers.removeValue(forKey: clusterableOverlayInfo)
        overlayController.deleteOverlay(info: overlayInfo)
        clusterer?.remove(clusterableOverlayInfo) // if needed use callback
        updateClusterer()
    }
    
    func clearClusterableMarker() {
        clusterableMarkers.removeAll()
        overlayController.clearOverlays(type: .clusterableMarker)
        clusterer?.clear()
        updateClusterer()
    }
    
    private func onClusterMarkerUpdate(_ clusterMarkerInfo: NMCClusterMarkerInfo, _ marker: NMFMarker) {
        guard let info = clusterMarkerInfo.tag as? NClusterInfo else { return }
        // iOS에서 클러스터 마커가 숨겨지는 문제를 막기 위해 오버레이를 저장하고 숨김을 해제한다.
        marker.iconImage = NMF_MARKER_IMAGE_BLACK // 아이콘이 없으면 표시되지 않으므로 기본 아이콘 지정
        marker.width = 36
        marker.height = 36
        marker.captionText = "\(info.clusterSize)"
        marker.captionColor = UIColor.white
        marker.captionHaloColor = UIColor.clear
        marker.iconTintColor = UIColor.black.withAlphaComponent(0.85)
        overlayController.saveOverlay(overlay: marker, info: info.markerInfo.messageOverlayInfo)
        marker.hidden = false
        sendClusterMarkerEvent(info: info)
    }
    
    private func sendClusterMarkerEvent(info: NClusterInfo) {
        messageSender("clusterMarkerBuilder", info.toMessageable())
    }
    
    private func onClusterableMarkerUpdate(_ clusterableMarkerInfo: NMCLeafMarkerInfo, _ marker: NMFMarker) {
        marker.iconImage = NMF_MARKER_IMAGE_BLACK
       let nClusterableMarker: NClusterableMarker = clusterableMarkerInfo.tag as! NClusterableMarker
       let nMarker: NMarker = nClusterableMarker.wrappedOverlay
       _ = overlayController.saveOverlayWithAddable(creator: nMarker, createdOverlay: marker)
    }
    
    func getThreshold(_ zoom: Int) -> Double {
        return mergedScreenDistanceCacheArray[zoom]
    }
    
    func mergeTag(_ cluster: NMCCluster) -> NSObject? {
        var mergedTagKey: String? = nil
        var children: [NClusterableMarkerInfo] = []
        
        for node in cluster.children {
            let data = node.tag
            switch data {
            case let data as NClusterableMarker:
                children.append(data.clusterInfo)
            case let data as NClusterInfo:
                if mergedTagKey == nil { mergedTagKey = data.mergedTagKey }
                children.append(contentsOf: data.children)
            default:
                print(data?.description ?? "empty tag")
            }
        }
        
        return NClusterInfo(
            children: children,
            clusterSize: children.count,
            position: cluster.position,
            mergedTagKey: mergedTagKey,
            mergedTag: nil
        )
    }
    
    func retainMarker(_ info: NMCMarkerInfo) -> NMFMarker? {
        let marker = NMFMarker(position: info.position)
        let data = info.tag
        switch data {
//         case let data as NClusterableMarker:
//             let nMarker: NMarker = data.wrappedOverlay
//             _ = overlayController.saveOverlayWithAddable(creator: nMarker, createdOverlay: marker)
        case let data as NClusterInfo:
            overlayController.saveOverlay(overlay: marker, info: data.markerInfo.messageOverlayInfo)
        default: ()
        }
        
        return marker
    }
    
    func releaseMarker(_ info: NMCMarkerInfo, _ marker: NMFMarker) {
        let data = info.tag
        switch data {
        case let data as NClusterableMarker:
            overlayController.deleteOverlay(info: data.info)
        case let data as NClusterInfo:
            overlayController.deleteOverlay(info: data.markerInfo.messageOverlayInfo)
        default:
            return;
        }
    }
    
    func dispose() {
        clusterer?.mapView = nil
        clusterer?.clear()
        clusterer = nil
        clusterableMarkers.removeAll()
    }
    
    deinit {
        dispose()
    }
}

class ClusterMarkerUpdater: NMCDefaultClusterMarkerUpdater {
    let callback: (_ clusterMarkerInfo: NMCClusterMarkerInfo, _ marker: NMFMarker) -> Void
    
    init(callback: @escaping (_: NMCClusterMarkerInfo, _: NMFMarker) -> Void) {
        self.callback = callback
    }
    
    override func updateClusterMarker(_ info: NMCClusterMarkerInfo, _ marker: NMFMarker) {
        super.updateClusterMarker(info, marker)
        callback(info, marker)
    }
}

class ClusterableMarkerUpdater: NMCDefaultLeafMarkerUpdater {
    let callback: (_ clusterableMarkerInfo: NMCLeafMarkerInfo, _ marker: NMFMarker) -> Void
    
    init(callback: @escaping (_: NMCLeafMarkerInfo, _: NMFMarker) -> Void) {
        self.callback = callback
    }
    
    override func updateLeafMarker(_ info: NMCLeafMarkerInfo, _ marker: NMFMarker) {
        super.updateLeafMarker(info, marker)
        callback(info, marker)
    }
}
