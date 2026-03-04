//
//  AppModel.swift
//  AlphaLocSnap
//
//  組合 LocationManager 與 BLEManager
//  整合通知、連線紀錄寫入、位置驅動 GPS 傳送

import CoreLocation
import Observation
import SwiftData
import SwiftUI
import UserNotifications

@Observable
final class AppModel: NSObject, UNUserNotificationCenterDelegate {
    let locationManager = LocationManager()
    let bleManager = BLEManager()
    let logStore = LogStore()

    /// 通知開關
    @ObservationIgnored
    @AppStorage("notifyOnConnect") var notifyOnConnect = true
    @ObservationIgnored
    @AppStorage("notifyOnDisconnect") var notifyOnDisconnect = true

    /// GPS 更新間隔（秒），對應 GPSUpdateMode.rawValue
    @ObservationIgnored
    @AppStorage("gpsUpdateInterval") var gpsUpdateInterval = GPSUpdateMode.standard.rawValue

    /// 自訂模式參數
    @ObservationIgnored
    @AppStorage("customAccuracy") var customAccuracy = AccuracyOption.best.rawValue
    @ObservationIgnored
    @AppStorage("customDistanceFilter") var customDistanceFilter: Double = 0.0
    @ObservationIgnored
    @AppStorage("customInterval") var customInterval: Int = 5

    /// 上次實際送出 GPS 封包的時間（throttle 用）
    @ObservationIgnored
    private var lastSentDate: Date = .distantPast

    /// SwiftData context，由 View 注入
    @ObservationIgnored
    var modelContext: ModelContext?

    override init() {
        super.init()

        // 套用儲存的 GPS 模式
        if let mode = GPSUpdateMode(rawValue: gpsUpdateInterval) {
            if mode == .custom {
                let accuracy = AccuracyOption(rawValue: customAccuracy)?.clAccuracy ?? kCLLocationAccuracyBest
                locationManager.applyCustom(accuracy: accuracy, distanceFilter: customDistanceFilter)
            } else {
                locationManager.applyMode(mode)
            }
        }

        // 設定通知代理，讓前景也能顯示通知
        UNUserNotificationCenter.current().delegate = self

        bleManager.locationProvider = { [weak self] in
            self?.locationManager.currentLocation
        }

        // 連線成功回調：寫入紀錄 + 發通知 + 啟動 GPS
        bleManager.onConnect = { [weak self] deviceName in
            self?.handleConnection(deviceName: deviceName)
        }

        // 斷線回調：發通知 + 停止 GPS
        bleManager.onDisconnect = { [weak self] deviceName in
            self?.handleDisconnection(deviceName: deviceName)
        }

        // 位置更新回調：驅動 GPS 傳送（含 throttle）
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self, self.bleManager.isTransmitting else { return }
            let seconds = self.gpsUpdateInterval == GPSUpdateMode.custom.rawValue
                ? self.customInterval
                : self.gpsUpdateInterval
            let interval = TimeInterval(seconds)
            guard Date().timeIntervalSince(self.lastSentDate) >= interval else { return }
            self.lastSentDate = Date()
            self.bleManager.sendGPSPacket()
            let coord = location.coordinate
            self.logStore.log(.gps, String(
                format: "傳送 %.5f, %.5f (±%.0fm)",
                coord.latitude, coord.longitude, location.horizontalAccuracy
            ))
        }

        locationManager.requestPermission()
    }

    /// 切換 GPS 模式時呼叫
    func applyGPSMode(_ mode: GPSUpdateMode) {
        gpsUpdateInterval = mode.rawValue
        if mode == .custom {
            applyCustomGPSSettings()
        } else {
            locationManager.applyMode(mode)
        }
        logStore.log(.gps, "GPS 模式切換為：\(mode.label)")
    }

    /// 套用自訂 GPS 參數
    func applyCustomGPSSettings() {
        let accuracy = AccuracyOption(rawValue: customAccuracy)?.clAccuracy ?? kCLLocationAccuracyBest
        locationManager.applyCustom(accuracy: accuracy, distanceFilter: customDistanceFilter)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 前景時也顯示通知 banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendConnectionNotification(deviceName: String) {
        guard notifyOnConnect else { return }

        let content = UNMutableNotificationContent()
        content.title = "Sony 相機已連線"
        content.body = "已連接到 \(deviceName)，GPS 傳送就緒"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendDisconnectionNotification(deviceName: String) {
        guard notifyOnDisconnect else { return }

        let content = UNMutableNotificationContent()
        content.title = "Sony 相機已斷線"
        content.body = "\(deviceName) 已中斷連線"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Connection Handling

    private func handleConnection(deviceName: String) {
        saveConnectionRecord(deviceName: deviceName)
        sendConnectionNotification(deviceName: deviceName)
        logStore.log(.connection, "\(deviceName) 已連線")
        locationManager.startUpdating()
    }

    private func handleDisconnection(deviceName: String) {
        sendDisconnectionNotification(deviceName: deviceName)
        logStore.log(.connection, "\(deviceName) 已斷線")
        locationManager.stopUpdating()
    }

    private func saveConnectionRecord(deviceName: String) {
        guard let context = modelContext,
              let location = locationManager.currentLocation else { return }

        let record = ConnectionRecord(
            deviceName: deviceName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        context.insert(record)
    }
}
