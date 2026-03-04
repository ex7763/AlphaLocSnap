//
//  LogStore.swift
//  AlphaLocSnap
//
//  記錄 App 運行事件（連線、斷線、GPS 更新等）
//  使用 JSON 檔案持久化

import CoreLocation
import Foundation
import Observation

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let category: Category
    let message: String

    enum Category: String, Codable {
        case connection = "連線"
        case gps = "GPS"
        case error = "錯誤"
    }

    init(timestamp: Date, category: Category, message: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }
}

@Observable
final class LogStore {
    private(set) var entries: [LogEntry] = []

    /// 最多保留筆數
    private let maxEntries = 500

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logs.json")
    }

    init() {
        load()
    }

    func log(_ category: LogEntry.Category, _ message: String) {
        let entry = LogEntry(timestamp: Date(), category: category, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    // MARK: - 持久化

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            // 寫入失敗不影響 App 運行
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Self.fileURL)
            entries = try JSONDecoder().decode([LogEntry].self, from: data)
        } catch {
            entries = []
        }
    }
}
