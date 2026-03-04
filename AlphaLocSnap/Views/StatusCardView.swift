//
//  StatusCardView.swift
//  AlphaLocSnap
//
//  顯示 BLE 連線狀態與操作按鈕
//

import SwiftUI
import CoreBluetooth

struct StatusCardView: View {
    @Environment(AppModel.self) private var appModel

    private var ble: BLEManager { appModel.bleManager }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(ble.bleState.displayText, systemImage: bleIcon)
                    .font(.headline)
                    .foregroundStyle(bleColor)

                if let error = ble.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch ble.bleState {
        case .poweredOn:
            Button(Strings.tr("scanning")) { ble.startScanning() }
                .buttonStyle(.borderedProminent)
        case .scanning:
            Button(Strings.tr("stop")) { ble.stopScanning() }
                .buttonStyle(.bordered)
        case .connected:
            Button(Strings.tr("disconnect"), role: .destructive) { ble.disconnect() }
                .buttonStyle(.bordered)
        case .disconnected:
            Button(Strings.tr("rescan")) {
                ble.startScanning()
            }
            .buttonStyle(.borderedProminent)
        default:
            EmptyView()
        }
    }

    private var bleIcon: String {
        switch ble.bleState {
        case .poweredOn, .scanning: return "antenna.radiowaves.left.and.right"
        case .connecting: return "antenna.radiowaves.left.and.right.slash"
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "exclamationmark.circle"
        case .poweredOff: return "bolt.slash"
        case .unauthorized, .unsupported: return "xmark.circle"
        default: return "questionmark.circle"
        }
    }

    private var bleColor: Color {
        switch ble.bleState {
        case .connected: return .green
        case .scanning, .connecting: return .blue
        case .disconnected: return .orange
        case .poweredOff, .unauthorized, .unsupported: return .red
        default: return .secondary
        }
    }
}
