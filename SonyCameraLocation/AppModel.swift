//
//  AppModel.swift
//  SonyCameraLocation
//
//  組合 LocationManager 與 BLEManager
//

import Observation

@Observable
final class AppModel {
    let locationManager = LocationManager()
    let bleManager = BLEManager()

    init() {
        bleManager.locationProvider = { [weak self] in
            self?.locationManager.currentLocation
        }
        locationManager.requestPermission()
    }
}
