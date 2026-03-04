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

    private var region: MapCameraPosition {
        guard let last = records.first else {
            // 預設台北
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }

        if records.count == 1 {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        let lats = records.map(\.latitude)
        let lons = records.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.01),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.01)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        Map(initialPosition: region) {
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
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
