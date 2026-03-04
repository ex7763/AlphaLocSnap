//
//  LocationManager.swift
//  AlphaLocSnap
//
//  CoreLocation 封裝，使用 @Observable
//  支援背景定位

import CoreLocation
import Observation

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
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = clManager.authorizationStatus
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
