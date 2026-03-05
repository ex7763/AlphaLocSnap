//
//  ConnectionMapView.swift
//  AlphaLocSnap
//
//  顯示最近連線紀錄的地圖視圖
//

import MapKit
import SwiftUI

struct ConnectionMapView: View {
    var records: [ConnectionRecord]
    @Binding var cameraPosition: MapCameraPosition
    var currentLocation: CLLocation?

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(records) { record in
                Marker(
                    record.deviceName,
                    systemImage: "camera.fill",
                    coordinate: CLLocationCoordinate2D(
                        latitude: record.latitude,
                        longitude: record.longitude
                    )
                )
            }
            if let loc = currentLocation {
                Marker(
                    Strings.tr("currentLocation"),
                    systemImage: "location.fill",
                    coordinate: loc.coordinate
                )
                .tint(.blue)
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    }
}
