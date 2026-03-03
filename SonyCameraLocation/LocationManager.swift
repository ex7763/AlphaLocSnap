//
//  LocationManager.swift
//  SonyCameraLocation
//
//  CoreLocation 封裝，使用 @Observable
//

import CoreLocation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager()

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = clManager.authorizationStatus
    }

    func requestPermission() {
        clManager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        clManager.startUpdatingLocation()
    }

    func stopUpdating() {
        clManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 忽略暫時性錯誤
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
    }
}
