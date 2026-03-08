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
    @AppStorage("customDistanceFilter") var customDistanceFilter: Double = 15.0
    @ObservationIgnored
    @AppStorage("customInterval") var customInterval: Int = 30

    /// 靜止偵測設定
    @ObservationIgnored
    @AppStorage("stationaryDetectionEnabled") var stationaryDetectionEnabled = true
    @ObservationIgnored
    @AppStorage("stationaryThresholdMinutes") var stationaryThresholdMinutes: Int = 2

    /// 上次實際送出 GPS 封包的時間（throttle 用）
    @ObservationIgnored
    private var lastSentDate: Date = .distantPast

    /// 等待 GPS 就緒後再建立連線紀錄的裝置名稱
    @ObservationIgnored
    private var pendingRecordDeviceName: String?

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

        // 套用靜止偵測設定
        applyStationarySettings()

        // GPS 系統事件日誌
        locationManager.onGPSEvent = { [weak self] message in
            self?.logStore.log(.gps, message)
        }

        // 靜止狀態變更回調
        locationManager.onStationaryStateChanged = { [weak self] isStationary in
            guard let self else { return }
            if isStationary {
                self.logStore.log(.gps, Strings.tr("stationaryEntered"))
            } else {
                self.logStore.log(.gps, Strings.tr("stationaryExited"))
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

        // 位置更新回調：建立待處理紀錄 + 驅動 GPS 傳送（含 throttle）
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self else { return }

            // GPS 就緒後建立延遲的連線紀錄
            if let deviceName = self.pendingRecordDeviceName {
                self.pendingRecordDeviceName = nil
                self.saveConnectionRecord(deviceName: deviceName)
            }

            guard self.bleManager.isTransmitting else { return }
            let seconds = self.gpsUpdateInterval == GPSUpdateMode.custom.rawValue
                ? self.customInterval
                : self.gpsUpdateInterval
            let interval = TimeInterval(seconds)
            guard Date().timeIntervalSince(self.lastSentDate) >= interval else { return }
            self.lastSentDate = Date()
            self.bleManager.sendGPSPacket()
            let coord = location.coordinate
            self.logStore.log(.gps, Strings.tr("gpsTransmit",
                coord.latitude, coord.longitude, location.horizontalAccuracy),
                coordinate: coord)
        }

        locationManager.requestPermission()
    }

    /// 切換 GPS 模式時呼叫
    func applyGPSMode(_ mode: GPSUpdateMode) {
        gpsUpdateInterval = mode.rawValue
        locationManager.resetStationaryDetection()
        if mode == .custom {
            applyCustomGPSSettings()
        } else {
            locationManager.applyMode(mode)
        }
        logStore.log(.gps, Strings.tr("gpsModeChanged", mode.label))
    }

    /// 套用自訂 GPS 參數
    func applyCustomGPSSettings() {
        let accuracy = AccuracyOption(rawValue: customAccuracy)?.clAccuracy ?? kCLLocationAccuracyBest
        locationManager.applyCustom(accuracy: accuracy, distanceFilter: customDistanceFilter)
    }

    /// 套用靜止偵測設定到 LocationManager
    func applyStationarySettings() {
        locationManager.stationaryDetectionEnabled = stationaryDetectionEnabled
        locationManager.stationaryThresholdDuration = TimeInterval(stationaryThresholdMinutes * 60)
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
        content.title = Strings.tr("cameraConnected")
        content.body = Strings.tr("cameraConnectedBody", deviceName)
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
        content.title = Strings.tr("cameraDisconnected")
        content.body = Strings.tr("cameraDisconnectedBody", deviceName)
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
        sendConnectionNotification(deviceName: deviceName)
        logStore.log(.connection, Strings.tr("deviceConnected", deviceName))
        locationManager.startUpdating()

        // 嘗試立即建立紀錄；若 GPS 尚未就緒則延後到第一次位置更新
        if locationManager.currentLocation != nil {
            saveConnectionRecord(deviceName: deviceName)
        } else {
            pendingRecordDeviceName = deviceName
        }

        // 連線時立即傳送一次位置
        if bleManager.isTransmitting, locationManager.currentLocation != nil {
            lastSentDate = Date()
            bleManager.sendGPSPacket()
            if let coord = locationManager.currentLocation?.coordinate {
                logStore.log(.gps, Strings.tr("gpsImmediateTransmit", coord.latitude, coord.longitude),
                    coordinate: coord)
            }
        }
    }

    private func handleDisconnection(deviceName: String) {
        pendingRecordDeviceName = nil
        markDisconnection(deviceName: deviceName)
        sendDisconnectionNotification(deviceName: deviceName)
        logStore.log(.connection, Strings.tr("deviceDisconnected", deviceName))
        locationManager.stopUpdating()
    }

    /// 短時間內重複連線的合併閾值（秒）
    private static let mergeThreshold: TimeInterval = 5 * 60

    private func saveConnectionRecord(deviceName: String) {
        guard let context = modelContext,
              let location = locationManager.currentLocation else { return }

        // 查詢同裝置最近的紀錄，若仍在連線中或斷線在閾值內則合併
        let threshold = Date().addingTimeInterval(-Self.mergeThreshold)

        // 先找仍在連線中的紀錄
        var activeDesc = FetchDescriptor<ConnectionRecord>(
            predicate: #Predicate<ConnectionRecord> {
                $0.deviceName == deviceName && $0.disconnectedAt == nil
            },
            sortBy: [SortDescriptor(\.connectedAt, order: .reverse)]
        )
        activeDesc.fetchLimit = 1

        // 再找最近斷線的紀錄
        var recentDesc = FetchDescriptor<ConnectionRecord>(
            predicate: #Predicate<ConnectionRecord> {
                $0.deviceName == deviceName && $0.connectedAt > threshold
            },
            sortBy: [SortDescriptor(\.connectedAt, order: .reverse)]
        )
        recentDesc.fetchLimit = 1

        let existing = (try? context.fetch(activeDesc).first)
            ?? (try? context.fetch(recentDesc).first)

        if let recent = existing {
            // 合併：清除斷線時間，更新座標
            recent.disconnectedAt = nil
            recent.latitude = location.coordinate.latitude
            recent.longitude = location.coordinate.longitude
        } else {
            let record = ConnectionRecord(
                deviceName: deviceName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            context.insert(record)
        }
        try? context.save()
    }

    private func markDisconnection(deviceName: String) {
        guard let context = modelContext else { return }

        var descriptor = FetchDescriptor<ConnectionRecord>(
            predicate: #Predicate {
                $0.deviceName == deviceName && $0.disconnectedAt == nil
            },
            sortBy: [SortDescriptor(\.connectedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let record = try? context.fetch(descriptor).first {
            record.disconnectedAt = Date()
            try? context.save()
        }
    }
}
