//
//  LocationManager.swift
//  AlphaLocSnap
//
//  CoreLocation 封裝，使用 @Observable
//  支援背景定位

import CoreLocation
import Observation

// MARK: - GPS 更新模式

enum GPSUpdateMode: Int, CaseIterable {
    case highFrequency = 2   // 2 秒
    case standard = 5        // 5 秒
    case powerSaving = 15    // 15 秒

    var label: String {
        switch self {
        case .highFrequency: "高頻（2 秒）"
        case .standard: "標準（5 秒）"
        case .powerSaving: "省電（15 秒）"
        }
    }

    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .highFrequency: kCLLocationAccuracyBest
        case .standard: kCLLocationAccuracyNearestTenMeters
        case .powerSaving: kCLLocationAccuracyHundredMeters
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .highFrequency: kCLDistanceFilterNone
        case .standard: 5.0
        case .powerSaving: 15.0
        }
    }
}

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager()

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 位置更新回調，供 AppModel 在背景中驅動 GPS 傳送
    @ObservationIgnored
    var onLocationUpdate: ((CLLocation) -> Void)?

    override init() {
        super.init()
        clManager.delegate = self
        clManager.activityType = .other
        clManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        clManager.distanceFilter = 5.0
        authorizationStatus = clManager.authorizationStatus
    }

    /// 根據 GPS 模式動態調整 CLLocationManager 設定
    func applyMode(_ mode: GPSUpdateMode) {
        clManager.desiredAccuracy = mode.desiredAccuracy
        clManager.distanceFilter = mode.distanceFilter
        clManager.pausesLocationUpdatesAutomatically = (mode == .powerSaving)
    }

    func requestPermission() {
        clManager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        clManager.startUpdatingLocation()
    }

    func stopUpdating() {
        clManager.stopUpdatingLocation()
    }

    private func configureBackgroundUpdates() {
        clManager.allowsBackgroundLocationUpdates = true
        clManager.pausesLocationUpdatesAutomatically = false
        clManager.showsBackgroundLocationIndicator = true
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 忽略暫時性錯誤
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            if manager.authorizationStatus == .authorizedAlways {
                configureBackgroundUpdates()
            }
            clManager.startUpdatingLocation()
        }
    }
}
