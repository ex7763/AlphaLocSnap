//
//  ContentView.swift
//  SonyCameraLocation
//

import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    private var ble: BLEManager { appModel.bleManager }
    private var loc: LocationManager { appModel.locationManager }

    var body: some View {
        NavigationStack {
            List {
                // MARK: 藍牙狀態
                Section("藍牙") {
                    StatusCardView()
                }

                // MARK: 附近裝置（掃描中才顯示）
                if ble.bleState == .scanning || !ble.discoveredDevices.isEmpty,
                   !ble.isConnected {
                    Section("附近裝置") {
                        DeviceListView()
                    }
                }

                // MARK: GPS 位置
                Section("GPS 位置") {
                    locationSection
                }

                // MARK: 傳輸（連線後才顯示）
                if ble.isConnected {
                    Section("傳輸") {
                        transmitSection
                    }
                }
            }
            .navigationTitle("Sony GPS 傳輸")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        switch loc.authorizationStatus {
        case .notDetermined:
            Button("授權位置權限") {
                loc.requestPermission()
            }
        case .denied, .restricted:
            Label("位置權限被拒絕，請至設定開啟", systemImage: "location.slash")
                .foregroundStyle(.red)
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = loc.currentLocation {
                LabeledContent("緯度") {
                    Text(String(format: "%.6f°", location.coordinate.latitude))
                        .monospacedDigit()
                }
                LabeledContent("經度") {
                    Text(String(format: "%.6f°", location.coordinate.longitude))
                        .monospacedDigit()
                }
                LabeledContent("精確度") {
                    Text(String(format: "±%.1f m", location.horizontalAccuracy))
                        .monospacedDigit()
                }
            } else {
                Label("等待 GPS 訊號...", systemImage: "location.circle")
                    .foregroundStyle(.secondary)
            }
        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Transmit Section

    @ViewBuilder
    private var transmitSection: some View {
        LabeledContent("相機狀態") {
            Label(
                ble.isCameraOn ? "已開機" : "未開機",
                systemImage: ble.isCameraOn ? "camera.fill" : "camera.slash"
            )
            .foregroundStyle(ble.isCameraOn ? .green : .red)
        }

        if ble.isCameraOn {
            HStack {
                Spacer()
                if ble.isTransmitting {
                    Button("停止傳輸", role: .destructive) {
                        ble.stopTransmitting()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("開始傳輸") {
                        ble.startTransmitting()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(loc.currentLocation == nil)
                }
                Spacer()
            }
        }

        LabeledContent("已傳送封包") {
            Text("\(ble.packetsSent)")
                .monospacedDigit()
                .foregroundStyle(.green)
        }

        if ble.packetsError > 0 {
            LabeledContent("傳送失敗") {
                Text("\(ble.packetsError)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
        }

        if let error = ble.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .preferredColorScheme(.light)
}
