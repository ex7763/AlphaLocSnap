//
//  AlphaLocSnapApp.swift
//  AlphaLocSnap
//
//  Created by 許博鈞 on 2026/3/3.
//

import SwiftData
import SwiftUI

@main
struct AlphaLocSnapApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .preferredColorScheme(.light)
                .onAppear {
                    appModel.requestNotificationPermission()
                }
        }
        .modelContainer(for: ConnectionRecord.self)
    }
}
