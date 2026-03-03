//
//  GATTConstants.swift
//  SonyCameraLocation
//

import CoreBluetooth

enum GATTConstants {
    /// 讀取此 characteristic 的最後 1 byte：0x00 = 相機開機，其他 = 關機
    static let connectionTestUUID = CBUUID(string: "0000cc05-0000-1000-8000-00805f9b34fb")

    /// 寫入 GPS 封包的 characteristic
    static let gpsWriteUUID = CBUUID(string: "0000dd11-0000-1000-8000-00805f9b34fb")

    /// 過濾 Sony 相機的名稱關鍵字
    static let cameraNameKeywords = ["ILCE", "ZV", "DSC", "WX", "HX", "Sony", "SONY"]
}
