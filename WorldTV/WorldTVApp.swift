//
//  WorldTVApp.swift
//  WorldTV
//
//  Created by Hernan Rodriguez on 28/07/2026.
//

import SwiftUI

@main
struct WorldTVApp: App {
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView(loadCatalogSummary: container.loadCatalogSummary)
        }
    }
}
