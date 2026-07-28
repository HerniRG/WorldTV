//
//  ContentView.swift
//  WorldTV
//
//  Created by Hernan Rodriguez on 28/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var homeViewModel: HomeViewModel
    private let loadCountries: LoadCountriesUseCase
    private let loadChannels: LoadChannelsByCountryUseCase
    private let imageLoader: any ImageLoading

    init(
        loadHomeContent: LoadHomeContentUseCase,
        loadCountries: LoadCountriesUseCase,
        loadChannels: LoadChannelsByCountryUseCase,
        imageLoader: any ImageLoading
    ) {
        _homeViewModel = State(
            initialValue: HomeViewModel(loadHomeContent: loadHomeContent)
        )
        self.loadCountries = loadCountries
        self.loadChannels = loadChannels
        self.imageLoader = imageLoader
    }

    var body: some View {
        NavigationStack {
            HomeView(viewModel: homeViewModel, imageLoader: imageLoader)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .countries:
                        CountriesView(loadCountries: loadCountries)
                    case .country(let code):
                        ChannelGridView(
                            countryCode: code,
                            loadChannels: loadChannels,
                            imageLoader: imageLoader
                        )
                    }
                }
        }
    }
}
