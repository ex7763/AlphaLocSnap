//
//  LogStore.swift
//  SonyCameraLocation
//
//  記錄 App 運行事件（連線、斷線、GPS 更新等）

import CoreLocation
import Foundation
import Observation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: Category
    let message: String

    enum Category: String {
        case connection = "連線"
        case gps = "GPS"
        case error = "錯誤"
    }
}

@Observable
final class LogStore {
    private(set) var entries: [LogEntry] = []

    /// 最多保留筆數
    private let maxEntries = 500

    func log(_ category: LogEntry.Category, _ message: String) {
        let entry = LogEntry(timestamp: Date(), category: category, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
