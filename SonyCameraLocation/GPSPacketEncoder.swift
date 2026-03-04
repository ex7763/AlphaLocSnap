//
//  GPSPacketEncoder.swift
//  SonyCameraLocation
//
//  Sony 相機 BLE GPS 封包編碼器（參考 Alpha-GPS 協定）
//
//  封包格式：
//    無 TZ/DST: 91 bytes, byte[1]=0x59, byte[5]=0x00
//    有 TZ/DST: 95 bytes, byte[1]=0x5D, byte[5]=0x03
//
//  Byte Layout (有 TZ/DST, 95 bytes):
//    [0]      0x00
//    [1]      0x5D (封包類型)
//    [2]      0x08
//    [3]      0x02
//    [4]      0xFC
//    [5]      0x03 (DST flag)
//    [6-7]    0x00 0x00
//    [8-10]   0x10 0x10 0x10
//    [11-14]  latitude  (Int32 BE, degrees * 1e7)
//    [15-18]  longitude (Int32 BE, degrees * 1e7)
//    [19-20]  year (UInt16 BE, UTC)
//    [21]     month (UTC)
//    [22]     day (UTC)
//    [23]     hour (UTC)
//    [24]     minute (UTC)
//    [25]     second (UTC)
//    [26-90]  padding 0x00
//    [91-92]  timezone offset (Int16 BE, minutes)
//    [93-94]  DST offset (Int16 BE, minutes)

import CoreLocation
import Foundation

enum GPSPacketEncoder {

    private static var utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 將 CLLocation 編碼成 Sony GPS 封包
    /// - Parameters:
    ///   - location: GPS 位置
    ///   - supportsDST: 相機是否支援 TZ/DST（從 dd21 characteristic 讀取）
    /// - Returns: 91 或 95 bytes 的 GPS 封包
    static func encode(location: CLLocation, supportsDST: Bool = true) -> Data {
        let packetSize = supportsDST ? 95 : 91
        var packet = Data(count: packetSize)

        // [0-1] Header
        packet[0] = 0x00
        packet[1] = supportsDST ? 0x5D : 0x59

        // [2-10] Fixed header (9 bytes) — 與 Alpha-GPS 一致共 11 bytes header
        let fixedHeader: [UInt8] = [
            0x08, 0x02, 0xFC,
            supportsDST ? 0x03 : 0x00,  // [5] DST flag
            0x00, 0x00,                  // [6-7] padding
            0x10, 0x10, 0x10             // [8-10]
        ]
        for (i, byte) in fixedHeader.enumerated() {
            packet[2 + i] = byte
        }

        // [11-14] Latitude * 1e7 → Int32 big-endian
        let latInt = Int32(location.coordinate.latitude * 1e7)
        withUnsafeBytes(of: latInt.bigEndian) { buf in
            for i in 0..<4 { packet[11 + i] = buf[i] }
        }

        // [15-18] Longitude * 1e7 → Int32 big-endian
        let lngInt = Int32(location.coordinate.longitude * 1e7)
        withUnsafeBytes(of: lngInt.bigEndian) { buf in
            for i in 0..<4 { packet[15 + i] = buf[i] }
        }

        // [19-25] Date/Time in UTC
        let now = Date()
        let comps = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: now
        )
        let year = UInt16(comps.year ?? 2026)
        withUnsafeBytes(of: year.bigEndian) { buf in
            packet[19] = buf[0]
            packet[20] = buf[1]
        }
        packet[21] = UInt8(comps.month ?? 1)
        packet[22] = UInt8(comps.day ?? 1)
        packet[23] = UInt8(comps.hour ?? 0)
        packet[24] = UInt8(comps.minute ?? 0)
        packet[25] = UInt8(comps.second ?? 0)

        // [26-90] padding (已由 Data(count:) 初始化為 0)

        // [91-94] Timezone / DST offsets（僅 supportsDST 時存在）
        if supportsDST {
            let secondsFromGMT = TimeZone.current.secondsFromGMT(for: now)
            let tzMinutes = Int16(secondsFromGMT / 60)
            withUnsafeBytes(of: tzMinutes.bigEndian) { buf in
                packet[91] = buf[0]
                packet[92] = buf[1]
            }

            let dstSeconds = TimeZone.current.daylightSavingTimeOffset(for: now)
            let dstMinutes = Int16(dstSeconds / 60)
            withUnsafeBytes(of: dstMinutes.bigEndian) { buf in
                packet[93] = buf[0]
                packet[94] = buf[1]
            }
        }

        return packet
    }

    /// 編碼時間同步封包（13 bytes），寫入 cc13 characteristic
    static func encodeTimeSync() -> Data {
        var packet = Data(count: 13)

        let now = Date()
        let utcComps = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: now
        )

        // [0] 封包類型
        packet[0] = 0x0C

        // [1-2] padding 0x00
        packet[1] = 0x00
        packet[2] = 0x00

        // [3-4] year (UInt16 BE)
        let year = UInt16(utcComps.year ?? 2026)
        withUnsafeBytes(of: year.bigEndian) { buf in
            packet[3] = buf[0]
            packet[4] = buf[1]
        }

        // [5-9] month, day, hour, minute, second
        packet[5] = UInt8(utcComps.month ?? 1)
        packet[6] = UInt8(utcComps.day ?? 1)
        packet[7] = UInt8(utcComps.hour ?? 0)
        packet[8] = UInt8(utcComps.minute ?? 0)
        packet[9] = UInt8(utcComps.second ?? 0)

        // [10] DST flag
        let dstOffset = TimeZone.current.daylightSavingTimeOffset(for: now)
        packet[10] = dstOffset > 0 ? 0x01 : 0x00

        // [11] Timezone offset hours (signed)
        let secondsFromGMT = TimeZone.current.secondsFromGMT(for: now)
        let totalMinutes = secondsFromGMT / 60
        let tzHours = Int8(totalMinutes / 60)
        packet[11] = UInt8(bitPattern: tzHours)

        // [12] Timezone offset minutes (absolute value of remainder)
        let tzMins = UInt8(abs(totalMinutes % 60))
        packet[12] = tzMins

        return packet
    }
}
