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

    // MARK: - 靜止偵測

    /// 目前是否處於靜止省電模式
    var isStationary = false

    /// 靜止偵測開關
    @ObservationIgnored
    var stationaryDetectionEnabled = true

    /// 靜止判定閾值時間（秒）
    @ObservationIgnored
    var stationaryThresholdDuration: TimeInterval = 120

    /// 靜止狀態變更回調
    @ObservationIgnored
    var onStationaryStateChanged: ((Bool) -> Void)?

    /// 靜止錨點位置
    @ObservationIgnored
    private var stationaryAnchor: CLLocation?

    /// 最後偵測到移動的時間
    @ObservationIgnored
    private var lastMovementDate = Date()

    /// 進入靜止前儲存的精度設定
    @ObservationIgnored
    private var savedAccuracy: CLLocationAccuracy?

    /// 進入靜止前儲存的距離過濾設定
    @ObservationIgnored
    private var savedDistanceFilter: CLLocationDistance?

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
        resetStationaryDetection()
        clManager.desiredAccuracy = mode.desiredAccuracy
        clManager.distanceFilter = mode.distanceFilter
        clManager.pausesLocationUpdatesAutomatically = (mode == .powerSaving)
    }

    /// 自訂模式：直接設定精度與距離過濾
    func applyCustom(accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance) {
        resetStationaryDetection()
        clManager.desiredAccuracy = accuracy
        clManager.distanceFilter = distanceFilter
        clManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - 靜止偵測邏輯

    /// 評估是否進入/退出靜止模式
    private func evaluateStationaryState(newLocation: CLLocation) {
        guard stationaryDetectionEnabled else { return }

        // 忽略低精度定位點
        guard newLocation.horizontalAccuracy >= 0,
              newLocation.horizontalAccuracy < 100 else { return }

        if isStationary {
            // 靜止模式：檢查是否有移動
            if let anchor = stationaryAnchor,
               newLocation.distance(from: anchor) >= 15 {
                exitStationaryMode()
            }
        } else {
            // 正常模式：追蹤是否靜止
            if let anchor = stationaryAnchor {
                if newLocation.distance(from: anchor) >= 10 {
                    // 有移動，重設錨點
                    stationaryAnchor = newLocation
                    lastMovementDate = Date()
                } else if Date().timeIntervalSince(lastMovementDate) >= stationaryThresholdDuration {
                    // 超過閾值未移動，進入靜止
                    enterStationaryMode()
                }
            } else {
                // 初始化錨點
                stationaryAnchor = newLocation
                lastMovementDate = Date()
            }
        }
    }

    private func enterStationaryMode() {
        savedAccuracy = clManager.desiredAccuracy
        savedDistanceFilter = clManager.distanceFilter
        clManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        clManager.distanceFilter = 500
        isStationary = true
        onStationaryStateChanged?(true)
    }

    private func exitStationaryMode() {
        if let accuracy = savedAccuracy {
            clManager.desiredAccuracy = accuracy
        }
        if let filter = savedDistanceFilter {
            clManager.distanceFilter = filter
        }
        savedAccuracy = nil
        savedDistanceFilter = nil
        isStationary = false
        stationaryAnchor = nil
        lastMovementDate = Date()
        onStationaryStateChanged?(false)
    }

    /// 重設靜止偵測狀態（模式切換時呼叫）
    func resetStationaryDetection() {
        if isStationary {
            // 直接清除狀態，不恢復設定（因為即將套用新設定）
            isStationary = false
            savedAccuracy = nil
            savedDistanceFilter = nil
        }
        stationaryAnchor = nil
        lastMovementDate = Date()
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
        evaluateStationaryState(newLocation: location)
        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 忽略暫時性錯誤
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways {
            configureBackgroundUpdates()
        }
    }
}
