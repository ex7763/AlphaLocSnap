//
//  LogView.swift
//  AlphaLocSnap
//
//  顯示 App 運行日誌

import SwiftUI

struct LogView: View {
    @Environment(AppModel.self) private var appModel

    private var logs: LogStore { appModel.logStore }

    var body: some View {
        List {
            if logs.entries.isEmpty {
                Text(Strings.tr("noLog"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs.entries.reversed()) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(for: entry.category))
                            .foregroundStyle(color(for: entry.category))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.message)
                                .font(.callout)
                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(Strings.tr("log"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !logs.entries.isEmpty {
                Button(Strings.tr("clear"), role: .destructive) {
                    logs.clear()
                }
            }
        }
    }

    private func icon(for category: LogEntry.Category) -> String {
        switch category {
        case .connection: return "antenna.radiowaves.left.and.right"
        case .gps: return "location.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for category: LogEntry.Category) -> Color {
        switch category {
        case .connection: return .blue
        case .gps: return .green
        case .error: return .red
        }
    }
}
