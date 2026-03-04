//
//  GATTConstants.swift
//  AlphaLocSnap
//
//  Sony 相機 BLE GATT 常數（參考 Alpha-GPS 協定）
//

import CoreBluetooth

enum GATTConstants {
    // MARK: - Service UUIDs

    /// Sony 相機控制 Service（含時間同步）
    static let sonyServiceCC = CBUUID(string: "8000CC00-CC00-FFFF-FFFF-FFFFFFFFFFFF")

    /// Sony 相機 GPS Service（含位置傳送、GPS 啟用）
    static let sonyServiceDD = CBUUID(string: "8000DD00-DD00-FFFF-FFFF-FFFFFFFFFFFF")

    static let sonyServiceUUIDs: [CBUUID] = [sonyServiceCC, sonyServiceDD]

    // MARK: - GPS Service Characteristics (DD)

    /// 寫入 GPS 封包的 characteristic
    static let gpsWriteUUID = CBUUID(string: "0000dd11-0000-1000-8000-00805f9b34fb")

    /// 讀取時區/DST 支援旗標（value[4] & 0x02 != 0 表示支援）
    static let timezoneReadUUID = CBUUID(string: "0000dd21-0000-1000-8000-00805f9b34fb")

    /// GPS Unlock 命令（寫入 0x01 啟用 GPS）
    static let unlockGPSUUID = CBUUID(string: "0000dd30-0000-1000-8000-00805f9b34fb")

    /// GPS Lock 命令（寫入 0x01 鎖定 GPS）
    static let lockGPSUUID = CBUUID(string: "0000dd31-0000-1000-8000-00805f9b34fb")

    /// 相機位置啟用狀態（Notify）
    static let locationEnabledUUID = CBUUID(string: "0000dd01-0000-1000-8000-00805f9b34fb")

    // MARK: - Control Service Characteristics (CC)

    /// 時間同步 characteristic（寫入 13 bytes 時間資料）
    static let timeSyncUUID = CBUUID(string: "0000cc13-0000-1000-8000-00805f9b34fb")

    /// 所有需要搜尋的 characteristic UUID
    static let allCharacteristicUUIDs: [CBUUID] = [
        gpsWriteUUID, timezoneReadUUID, unlockGPSUUID, lockGPSUUID,
        locationEnabledUUID, timeSyncUUID
    ]

    // MARK: - Device Filtering

    /// 過濾 Sony 相機的名稱關鍵字
    static let cameraNameKeywords = ["ILCE", "ZV", "DSC", "WX", "HX", "Sony", "SONY"]
}
