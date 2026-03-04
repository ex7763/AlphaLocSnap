//
//  DeviceListView.swift
//  AlphaLocSnap
//
//  顯示掃描到的 BLE 裝置列表
//

import SwiftUI

struct DeviceListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showOnlySony = true

    private var ble: BLEManager { appModel.bleManager }

    private var filteredDevices: [DiscoveredDevice] {
        if showOnlySony {
            return ble.discoveredDevices.filter { $0.isSonyCamera }
        }
        return ble.discoveredDevices
    }

    var body: some View {
        Toggle(Strings.tr("showOnlySony"), isOn: $showOnlySony)
            .toggleStyle(.switch)

        if filteredDevices.isEmpty {
            Text(showOnlySony ? Strings.tr("noSonyFound") : Strings.tr("noDeviceFound"))
                .foregroundStyle(.secondary)
                .font(.subheadline)
        } else {
            ForEach(filteredDevices) { device in
                Button {
                    ble.connect(to: device)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if device.isSonyCamera {
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                }
                                Text(device.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            Text(device.id.uuidString.prefix(8) + "...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        SignalStrengthView(rssi: device.rssi)
                    }
                }
            }
        }
    }
}

struct SignalStrengthView: View {
    let rssi: Int

    private var bars: Int {
        switch rssi {
        case (-50)...: return 4
        case (-65)...: return 3
        case (-75)...: return 2
        default: return 1
        }
    }

    private var color: Color {
        switch rssi {
        case (-50)...: return .green
        case (-65)...: return .yellow
        case (-75)...: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1 ... 4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bar <= bars ? color : Color.secondary.opacity(0.3))
                    .frame(width: 5, height: CGFloat(bar) * 4)
            }
            Text("\(rssi) dBm")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
        }
    }
}
