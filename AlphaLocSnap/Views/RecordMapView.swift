//
//  RecordMapView.swift
//  AlphaLocSnap
//
//  顯示 GPS 傳送日誌的地圖視圖
//

import MapKit
import SwiftUI

struct RecordMapView: View {
    @Environment(AppModel.self) private var appModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedEntryID: UUID?

    private var gpsEntries: [LogEntry] {
        appModel.logStore.entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var currentLocation: CLLocation? {
        appModel.locationManager.currentLocation
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                ForEach(gpsEntries) { entry in
                    if let lat = entry.latitude, let lon = entry.longitude {
                        Annotation(
                            entry.timestamp.formatted(.dateTime.hour().minute().second()),
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        ) {
                            Circle()
                                .fill(entry.id == selectedEntryID ? .red : .blue)
                                .frame(width: entry.id == selectedEntryID ? 14 : 10,
                                       height: entry.id == selectedEntryID ? 14 : 10)
                                .overlay(
                                    Circle().stroke(.white, lineWidth: 2)
                                )
                        }
                    }
                }
                if let loc = currentLocation {
                    Marker(
                        Strings.tr("currentLocation"),
                        systemImage: "location.fill",
                        coordinate: loc.coordinate
                    )
                    .tint(.green)
                }
            }
            .frame(minHeight: 300)
            .overlay(alignment: .topTrailing) {
                Button {
                    if let loc = currentLocation {
                        withAnimation {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: loc.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                        }
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(8)
                .disabled(currentLocation == nil)
            }

            Divider()

            if gpsEntries.isEmpty {
                ContentUnavailableView(
                    Strings.tr("noGPSRecord"),
                    systemImage: "map",
                    description: Text("")
                )
            } else {
                List(gpsEntries.reversed()) { entry in
                    Button {
                        if let lat = entry.latitude, let lon = entry.longitude {
                            selectedEntryID = entry.id
                            withAnimation {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                ))
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text(String(format: "%.5f, %.5f", entry.latitude ?? 0, entry.longitude ?? 0))
                                    .monospacedDigit()
                                    .font(.caption)
                            }
                            Text(entry.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(entry.timestamp, format: .dateTime.month().day().hour().minute().second())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(Strings.tr("recordMap"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let last = gpsEntries.last, let lat = last.latitude, let lon = last.longitude {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
}
