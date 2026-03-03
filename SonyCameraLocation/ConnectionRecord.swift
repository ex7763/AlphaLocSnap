//
//  ConnectionRecord.swift
//  SonyCameraLocation
//
//  BLE 連線紀錄的 SwiftData 模型
//

import Foundation
import SwiftData

@Model
final class ConnectionRecord {
    var deviceName: String
    var latitude: Double
    var longitude: Double
    var connectedAt: Date

    init(deviceName: String, latitude: Double, longitude: Double, connectedAt: Date = .now) {
        self.deviceName = deviceName
        self.latitude = latitude
        self.longitude = longitude
        self.connectedAt = connectedAt
    }
}
