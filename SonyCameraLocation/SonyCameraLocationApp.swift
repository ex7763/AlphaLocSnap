//
//  SonyCameraLocationApp.swift
//  SonyCameraLocation
//
//  Created by 許博鈞 on 2026/3/3.
//

import SwiftUI

@main
struct SonyCameraLocationApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .preferredColorScheme(.light)
        }
    }
}
