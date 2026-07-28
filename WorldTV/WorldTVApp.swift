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
            ContentView(
                loadHomeContent: container.loadHomeContent,
                loadCountries: container.loadCountries,
                loadChannels: container.loadChannelsByCountry,
                imageLoader: container.imageLoader,
                resolvePlaybackSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched
            )
        }
    }
}
