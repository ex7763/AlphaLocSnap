//
//  ConnectionRecord.swift
//  AlphaLocSnap
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
    var disconnectedAt: Date?

    init(deviceName: String, latitude: Double, longitude: Double, connectedAt: Date = .now) {
        self.deviceName = deviceName
        self.latitude = latitude
        self.longitude = longitude
        self.connectedAt = connectedAt
        self.disconnectedAt = nil
    }

    /// 是否仍在連線中（尚未斷線）
    var isActive: Bool { disconnectedAt == nil }

    /// 連線時長（秒），如仍在連線中則計算至今
    var duration: TimeInterval {
        let end = disconnectedAt ?? Date()
        return end.timeIntervalSince(connectedAt)
    }
}
