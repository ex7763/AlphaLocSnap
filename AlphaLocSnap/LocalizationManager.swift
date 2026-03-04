//
//  LocalizationManager.swift
//  AlphaLocSnap
//
//  語言切換管理
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        }
    }
}

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    var language: AppLanguage {
        get {
            AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .traditionalChinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
        }
    }

    private init() {}
}

struct Strings {
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let lang = LocalizationManager.shared.language
        var value: String
        switch lang {
        case .traditionalChinese:
            value = zhHant[key] ?? key
        case .english:
            value = en[key] ?? key
        }
        if args.isEmpty {
            return value
        }
        return String(format: value, arguments: args)
    }

    static let zhHant: [String: String] = [
        // Status
        "bluetooth": "藍牙",
        "scanning": "掃描",
        "stop": "停止",
        "disconnect": "斷開",
        "rescan": "重新掃描",
        
        // BLE States
        "unknown": "未知",
        "unsupported": "不支援藍牙",
        "unauthorized": "藍牙未授權",
        "poweredOff": "藍牙已關閉",
        "poweredOn": "藍牙已開啟",
        "scanningEllipsis": "掃描中...",
        "connectingEllipsis": "連線中...",
        "connected": "已連線",
        "disconnected": "已斷線",

        // Sections
        "nearbyDevices": "附近裝置",
        "gpsLocation": "GPS 位置",
        "transmission": "傳輸",
        "settings": "設定",
        "connectionHistory": "連線紀錄",

        // GPS Settings
        "gpsUpdateMode": "GPS 更新模式",
        "gpsModeHighFreq": "高頻（2 秒）",
        "gpsModeStandard": "標準（5 秒）",
        "gpsModePowerSaving": "省電（15 秒）",
        "gpsModeCustom": "自訂",
        "locationAccuracy": "定位精度",
        "accuracyBest": "最佳",
        "accuracy10m": "10 公尺",
        "accuracy100m": "100 公尺",
        "accuracy1km": "1 公里",
        "accuracy3km": "3 公里",
        "distanceFilter": "距離過濾",
        "updateInterval": "更新間隔",
        "noFilter": "無",
        "seconds": "秒",

        // Toggles
        "connectionNotification": "連線通知",
        "disconnectionNotification": "斷線通知",
        "autoReconnect": "自動重連",

        // Location
        "authorizeLocation": "授權位置權限",
        "locationDenied": "位置權限被拒絕，請至設定開啟",
        "latitude": "緯度",
        "longitude": "經度",
        "accuracy": "精確度",
        "waitingForGPS": "等待 GPS 訊號...",

        // Transmission
        "cameraStatus": "相機狀態",
        "cameraOn": "已開機",
        "cameraOff": "未開機",
        "startTransmit": "開始傳輸",
        "stopTransmit": "停止傳輸",
        "packetsSent": "已傳送封包",
        "transmitFailed": "傳送失敗",

        // Device List
        "showOnlySony": "只顯示 Sony 相機",
        "noSonyFound": "未發現 Sony 相機",
        "noDeviceFound": "未發現裝置",

        // Log
        "log": "日誌",
        "noLog": "尚無日誌",
        "clear": "清除",

        // Connection History
        "noConnectionHistory": "尚無連線紀錄",

        // Notifications
        "cameraConnected": "Sony 相機已連線",
        "cameraConnectedBody": "已連接到 %@，GPS 傳送就緒",
        "cameraDisconnected": "Sony 相機已斷線",
        "cameraDisconnectedBody": "%@ 已中斷連線",

        // GPS
        "gpsModeChanged": "GPS 模式切換為：%@",
        "gpsTransmit": "傳送 %.5f, %.5f (±%.0fm)",
        "gpsImmediateTransmit": "連線立即傳送 %.5f, %.5f",

        // Connection
        "deviceConnected": "%@ 已連線",
        "deviceDisconnected": "%@ 已斷線",
        
        // Errors
        "connectionFailed": "連線失敗：%@",
        "connectionLost": "連線中斷",
        "gpsUnlockFailed": "GPS Unlock 失敗：%@",
        "gpsLockFailed": "GPS Lock 失敗：%@",
        "transmitFailedError": "傳送失敗：%@",

        // App Title
        "appTitle": "Sony GPS 傳輸",
        "language": "語言",

        // Restart Alert
        "restartRequired": "需要重新啟動",
        "restartMessage": "需要重新啟動應用程式才能套用語言變更。",
        "restartNow": "立即重新啟動",
        "restartLater": "稍後"
    ]

    static let en: [String: String] = [
        // Status
        "bluetooth": "Bluetooth",
        "scanning": "Scan",
        "stop": "Stop",
        "disconnect": "Disconnect",
        "rescan": "Rescan",
        
        // BLE States
        "unknown": "Unknown",
        "unsupported": "Bluetooth Not Supported",
        "unauthorized": "Bluetooth Not Authorized",
        "poweredOff": "Bluetooth Off",
        "poweredOn": "Bluetooth On",
        "scanningEllipsis": "Scanning...",
        "connectingEllipsis": "Connecting...",
        "connected": "Connected",
        "disconnected": "Disconnected",

        // Sections
        "nearbyDevices": "Nearby Devices",
        "gpsLocation": "GPS Location",
        "transmission": "Transmission",
        "settings": "Settings",
        "connectionHistory": "Connection History",

        // GPS Settings
        "gpsUpdateMode": "GPS Update Mode",
        "gpsModeHighFreq": "High Frequency (2 sec)",
        "gpsModeStandard": "Standard (5 sec)",
        "gpsModePowerSaving": "Power Saving (15 sec)",
        "gpsModeCustom": "Custom",
        "locationAccuracy": "Location Accuracy",
        "accuracyBest": "Best",
        "accuracy10m": "10 Meters",
        "accuracy100m": "100 Meters",
        "accuracy1km": "1 Kilometer",
        "accuracy3km": "3 Kilometers",
        "distanceFilter": "Distance Filter",
        "updateInterval": "Update Interval",
        "noFilter": "None",
        "seconds": "sec",

        // Toggles
        "connectionNotification": "Connection Notification",
        "disconnectionNotification": "Disconnection Notification",
        "autoReconnect": "Auto Reconnect",

        // Location
        "authorizeLocation": "Authorize Location",
        "locationDenied": "Location denied, please enable in Settings",
        "latitude": "Latitude",
        "longitude": "Longitude",
        "accuracy": "Accuracy",
        "waitingForGPS": "Waiting for GPS...",

        // Transmission
        "cameraStatus": "Camera Status",
        "cameraOn": "On",
        "cameraOff": "Off",
        "startTransmit": "Start Transmission",
        "stopTransmit": "Stop Transmission",
        "packetsSent": "Packets Sent",
        "transmitFailed": "Transmission Failed",

        // Device List
        "showOnlySony": "Show Sony Cameras Only",
        "noSonyFound": "No Sony Camera Found",
        "noDeviceFound": "No Device Found",

        // Log
        "log": "Log",
        "noLog": "No Log",
        "clear": "Clear",

        // Connection History
        "noConnectionHistory": "No Connection History",

        // Notifications
        "cameraConnected": "Sony Camera Connected",
        "cameraConnectedBody": "Connected to %@, GPS ready",
        "cameraDisconnected": "Sony Camera Disconnected",
        "cameraDisconnectedBody": "%@ disconnected",

        // GPS
        "gpsModeChanged": "GPS mode changed to: %@",
        "gpsTransmit": "Transmit %.5f, %.5f (±%.0fm)",
        "gpsImmediateTransmit": "Immediate transmit %.5f, %.5f",

        // Connection
        "deviceConnected": "%@ connected",
        "deviceDisconnected": "%@ disconnected",
        
        // Errors
        "connectionFailed": "Connection failed: %@",
        "connectionLost": "Connection lost",
        "gpsUnlockFailed": "GPS Unlock failed: %@",
        "gpsLockFailed": "GPS Lock failed: %@",
        "transmitFailedError": "Transmission failed: %@",

        // App Title
        "appTitle": "Sony GPS Transfer",
        "language": "Language",

        // Restart Alert
        "restartRequired": "Restart Required",
        "restartMessage": "You need to restart the app for the language change to take effect.",
        "restartNow": "Restart Now",
        "restartLater": "Later"
    ]
}
