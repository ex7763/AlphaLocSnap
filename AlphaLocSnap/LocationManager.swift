//
//  LocationManager.swift
//  AlphaLocSnap
//
//  CoreLocation 封裝，使用 @Observable
//  支援背景定位

import CoreLocation
import Observation
import SwiftUI

// MARK: - GPS 更新模式

enum GPSUpdateMode: Int, CaseIterable {
    case highFrequency = 2   // 2 秒
    case standard = 5        // 5 秒
    case powerSaving = 15    // 15 秒
    case custom = 0          // 使用者自訂

    var label: String {
        switch self {
        case .highFrequency: Strings.tr("gpsModeHighFreq")
        case .standard: Strings.tr("gpsModeStandard")
        case .powerSaving: Strings.tr("gpsModePowerSaving")
        case .custom: Strings.tr("gpsModeCustom")
        }
    }

    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .highFrequency: kCLLocationAccuracyBest
        case .standard: kCLLocationAccuracyNearestTenMeters
        case .powerSaving: kCLLocationAccuracyHundredMeters
        case .custom: kCLLocationAccuracyBest // 預設值，實際由使用者設定覆蓋
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .highFrequency: kCLDistanceFilterNone
        case .standard: 5.0
        case .powerSaving: 15.0
        case .custom: kCLDistanceFilterNone // 預設值，實際由使用者設定覆蓋
        }
    }
}

/// desiredAccuracy 的使用者可選選項
enum AccuracyOption: Int, CaseIterable {
    case best = 0
    case tenMeters = 1
    case hundredMeters = 2
    case kilometer = 3
    case threeKilometers = 4

    var label: String {
        switch self {
        case .best: Strings.tr("accuracyBest")
        case .tenMeters: Strings.tr("accuracy10m")
        case .hundredMeters: Strings.tr("accuracy100m")
        case .kilometer: Strings.tr("accuracy1km")
        case .threeKilometers: Strings.tr("accuracy3km")
        }
    }

    var clAccuracy: CLLocationAccuracy {
        switch self {
        case .best: kCLLocationAccuracyBest
        case .tenMeters: kCLLocationAccuracyNearestTenMeters
        case .hundredMeters: kCLLocationAccuracyHundredMeters
        case .kilometer: kCLLocationAccuracyKilometer
        case .threeKilometers: kCLLocationAccuracyThreeKilometers
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

    /// 自訂模式：直接設定精度與距離過濾
    func applyCustom(accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance) {
        clManager.desiredAccuracy = accuracy
        clManager.distanceFilter = distanceFilter
        clManager.pausesLocationUpdatesAutomatically = false
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
        clManager.showsBackgroundLocationIndicator = false
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
