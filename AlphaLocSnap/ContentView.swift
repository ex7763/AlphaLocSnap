//
//  ContentView.swift
//  AlphaLocSnap
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectionRecord.connectedAt, order: .reverse)
    private var allRecords: [ConnectionRecord]

    @AppStorage("notifyOnConnect") private var notifyOnConnect = true
    @AppStorage("notifyOnDisconnect") private var notifyOnDisconnect = true
    @AppStorage("gpsUpdateInterval") private var gpsUpdateInterval = GPSUpdateMode.standard.rawValue
    @AppStorage("customAccuracy") private var customAccuracy = AccuracyOption.best.rawValue
    @AppStorage("customDistanceFilter") private var customDistanceFilter: Double = 0.0
    @AppStorage("customInterval") private var customInterval: Int = 5

    @State private var showLanguagePicker = false

    private var ble: BLEManager { appModel.bleManager }
    private var loc: LocationManager { appModel.locationManager }

    private var recentRecords: [ConnectionRecord] {
        Array(allRecords.prefix(10))
    }

    var body: some View {
        NavigationStack {
            List {
                Section(Strings.tr("bluetooth")) {
                    StatusCardView()
                }

                if ble.bleState == .scanning || !ble.discoveredDevices.isEmpty,
                   !ble.isConnected {
                    Section(Strings.tr("nearbyDevices")) {
                        DeviceListView()
                    }
                }

                Section(Strings.tr("gpsLocation")) {
                    locationSection
                }

                if ble.isConnected {
                    Section(Strings.tr("transmission")) {
                        transmitSection
                    }
                }

                Section(Strings.tr("settings")) {
                    Picker(Strings.tr("gpsUpdateMode"), selection: $gpsUpdateInterval) {
                        ForEach(GPSUpdateMode.allCases, id: \.rawValue) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .onChange(of: gpsUpdateInterval) { _, newValue in
                        if let mode = GPSUpdateMode(rawValue: newValue) {
                            appModel.applyGPSMode(mode)
                        }
                    }

                    if gpsUpdateInterval == GPSUpdateMode.custom.rawValue {
                        Picker(Strings.tr("locationAccuracy"), selection: $customAccuracy) {
                            ForEach(AccuracyOption.allCases, id: \.rawValue) { option in
                                Text(option.label).tag(option.rawValue)
                            }
                        }
                        .onChange(of: customAccuracy) { _, _ in
                            appModel.applyCustomGPSSettings()
                        }

                        Stepper(
                            "\(Strings.tr("distanceFilter")): \(customDistanceFilter == 0 ? Strings.tr("noFilter") : String(format: "%.0f m", customDistanceFilter))",
                            value: $customDistanceFilter,
                            in: 0...100,
                            step: 5
                        )
                        .onChange(of: customDistanceFilter) { _, _ in
                            appModel.applyCustomGPSSettings()
                        }

                        Stepper(
                            "\(Strings.tr("updateInterval")): \(customInterval) \(Strings.tr("seconds"))",
                            value: $customInterval,
                            in: 1...60
                        )
                    }

                    Toggle(Strings.tr("connectionNotification"), isOn: $notifyOnConnect)
                    Toggle(Strings.tr("disconnectionNotification"), isOn: $notifyOnDisconnect)
                    Toggle(Strings.tr("autoReconnect"), isOn: Bindable(ble).autoConnectEnabled)

                    Button {
                        showLanguagePicker = true
                    } label: {
                        HStack {
                            Label(Strings.tr("language"), systemImage: "globe")
                            Spacer()
                            Text(LocalizationManager.shared.language.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        LogView()
                    } label: {
                        HStack {
                            Label(Strings.tr("log"), systemImage: "doc.text")
                            Spacer()
                            Text("\(appModel.logStore.entries.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(Strings.tr("connectionHistory")) {
                    if recentRecords.isEmpty {
                        Label(Strings.tr("noConnectionHistory"), systemImage: "clock")
                            .foregroundStyle(.secondary)
                    } else {
                        ConnectionMapView(records: recentRecords)
                            .listRowInsets(EdgeInsets())

                        ForEach(recentRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.deviceName)
                                    .font(.headline)
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.blue)
                                    Text(String(format: "%.4f, %.4f", record.latitude, record.longitude))
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                    Text(record.connectedAt, format: .dateTime.month().day().hour().minute())
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(Strings.tr("appTitle"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerView()
            }
            .onAppear {
                appModel.modelContext = modelContext
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        switch loc.authorizationStatus {
        case .notDetermined:
            Button(Strings.tr("authorizeLocation")) {
                loc.requestPermission()
            }
        case .denied, .restricted:
            Label(Strings.tr("locationDenied"), systemImage: "location.slash")
                .foregroundStyle(.red)
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = loc.currentLocation {
                LabeledContent(Strings.tr("latitude")) {
                    Text(String(format: "%.6f°", location.coordinate.latitude))
                        .monospacedDigit()
                }
                LabeledContent(Strings.tr("longitude")) {
                    Text(String(format: "%.6f°", location.coordinate.longitude))
                        .monospacedDigit()
                }
                LabeledContent(Strings.tr("accuracy")) {
                    Text(String(format: "±%.1f m", location.horizontalAccuracy))
                        .monospacedDigit()
                }
            } else {
                Label(Strings.tr("waitingForGPS"), systemImage: "location.circle")
                    .foregroundStyle(.secondary)
            }
        @unknown default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var transmitSection: some View {
        LabeledContent(Strings.tr("cameraStatus")) {
            Label(
                ble.isCameraOn ? Strings.tr("cameraOn") : Strings.tr("cameraOff"),
                systemImage: ble.isCameraOn ? "camera.fill" : "camera.slash"
            )
            .foregroundStyle(ble.isCameraOn ? .green : .red)
        }

        if ble.isCameraOn {
            HStack {
                Spacer()
                if ble.isTransmitting {
                    Button(Strings.tr("stopTransmit"), role: .destructive) {
                        ble.stopTransmitting()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(Strings.tr("startTransmit")) {
                        ble.startTransmitting()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(loc.currentLocation == nil)
                }
                
            }
        }

        LabeledContent(Strings.tr("packetsSent")) {
            Text("\(ble.packetsSent)")
                .monospacedDigit()
                .foregroundStyle(.green)
        }

        if ble.packetsError > 0 {
            LabeledContent(Strings.tr("transmitFailed")) {
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

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage = LocalizationManager.shared.language

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        selectedLanguage = language
                    } label: {
                        HStack {
                            Text(language.displayName)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(Strings.tr("language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        LocalizationManager.shared.language = selectedLanguage
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedLanguage = LocalizationManager.shared.language
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .modelContainer(for: ConnectionRecord.self, inMemory: true)
        .preferredColorScheme(.light)
}
