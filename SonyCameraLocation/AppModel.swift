//
//  AppModel.swift
//  SonyCameraLocation
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

    /// 通知開關
    @ObservationIgnored
    @AppStorage("notifyOnConnect") var notifyOnConnect = true

    /// SwiftData context，由 View 注入
    @ObservationIgnored
    var modelContext: ModelContext?

    override init() {
        super.init()

        // 設定通知代理，讓前景也能顯示通知
        UNUserNotificationCenter.current().delegate = self

        bleManager.locationProvider = { [weak self] in
            self?.locationManager.currentLocation
        }

        // 連線成功回調：寫入紀錄 + 發通知
        bleManager.onConnect = { [weak self] deviceName in
            self?.handleConnection(deviceName: deviceName)
        }

        // 位置更新回調：驅動 GPS 傳送（取代 Timer）
        locationManager.onLocationUpdate = { [weak self] _ in
            guard let self, self.bleManager.isTransmitting else { return }
            self.bleManager.sendGPSPacket()
        }

        locationManager.requestPermission()
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

    // MARK: - Connection Handling

    private func handleConnection(deviceName: String) {
        saveConnectionRecord(deviceName: deviceName)
        sendConnectionNotification(deviceName: deviceName)
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
