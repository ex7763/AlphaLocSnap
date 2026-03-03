//
//  GPSPacketEncoder.swift
//  SonyCameraLocation
//
//  將 GPS 座標編碼成 Sony 相機所需的 95 bytes BLE 封包
//

import CoreLocation
import Foundation

enum GPSPacketEncoder {
    /// 將 CLLocation 與當前時間編碼成 95 bytes 的 Sony GPS 封包
    static func encode(location: CLLocation) -> Data {
        var packet = Data(count: 95)

        // [0] = 0x00, [1] = 0x5D
        packet[0] = 0x00
        packet[1] = 0x5D

        // [2:11] 固定 header bytes
        let fixedHeader: [UInt8] = [0x08, 0x02, 0xFC, 0x03, 0x00, 0x00, 0x10, 0x10, 0x10]
        for (i, byte) in fixedHeader.enumerated() {
            packet[2 + i] = byte
        }

        // [11:15] latitude * 1e7 → Int32 big-endian signed
        let latInt = Int32(location.coordinate.latitude * 1e7)
        let latBytes = withUnsafeBytes(of: latInt.bigEndian) { Array($0) }
        for (i, byte) in latBytes.enumerated() {
            packet[11 + i] = byte
        }

        // [15:19] longitude * 1e7 → Int32 big-endian signed
        let lngInt = Int32(location.coordinate.longitude * 1e7)
        let lngBytes = withUnsafeBytes(of: lngInt.bigEndian) { Array($0) }
        for (i, byte) in lngBytes.enumerated() {
            packet[15 + i] = byte
        }

        // [19:26] 日期時間（使用裝置本地時區）
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)

        let year = UInt16(comps.year ?? 2026)
        let yearBytes = withUnsafeBytes(of: year.bigEndian) { Array($0) }
        packet[19] = yearBytes[0]
        packet[20] = yearBytes[1]
        packet[21] = UInt8(comps.month ?? 1)
        packet[22] = UInt8(comps.day ?? 1)
        packet[23] = UInt8(comps.hour ?? 0)
        packet[24] = UInt8(comps.minute ?? 0)
        packet[25] = UInt8(comps.second ?? 0)

        // [26:91] 填充 0x00（已由 Data(count:) 初始化為 0）

        // [91:93] 時區偏移（分鐘，Int16 → UInt16 bitPattern，big-endian）
        let secondsFromGMT = TimeZone.current.secondsFromGMT(for: now)
        let tzMinutes = Int16(secondsFromGMT / 60)
        let tzUInt16 = UInt16(bitPattern: tzMinutes)
        let tzBytes = withUnsafeBytes(of: tzUInt16.bigEndian) { Array($0) }
        packet[91] = tzBytes[0]
        packet[92] = tzBytes[1]

        // [93:95] DST 偏移（分鐘，UInt16 big-endian）
        let dstSeconds = TimeZone.current.daylightSavingTimeOffset(for: now)
        let dstMinutes = UInt16(max(0, Int(dstSeconds / 60)))
        let dstBytes = withUnsafeBytes(of: dstMinutes.bigEndian) { Array($0) }
        packet[93] = dstBytes[0]
        packet[94] = dstBytes[1]

        return packet
    }
}
