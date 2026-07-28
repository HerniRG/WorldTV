import SwiftUI

struct ChannelGridView: View {
    @State private var viewModel: ChannelGridViewModel
    private let imageLoader: any ImageLoading

    init(
        countryCode: String,
        loadChannels: LoadChannelsByCountryUseCase,
        imageLoader: any ImageLoading
    ) {
        _viewModel = State(
            initialValue: ChannelGridViewModel(
                countryCode: countryCode,
                loadChannels: loadChannels
            )
        )
        self.imageLoader = imageLoader
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("catalog.loading")
            case .loaded(let content):
                channelGrid(title: localizedName(for: content.country))
            case .empty:
                ContentUnavailableView("channels.empty", systemImage: "tv.slash")
            case .failed:
                ContentUnavailableView {
                    Label("catalog.error.title", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("action.retry") {
                        viewModel.retry()
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "channels.search")
        .task(id: stateIsIdle) {
            await viewModel.loadIfNeeded()
        }
    }

    private var stateIsIdle: Bool {
        if case .idle = viewModel.state {
            return true
        }
        return false
    }

    private func channelGrid(title: String) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190), spacing: DesignTokens.contentSpacing)],
                spacing: DesignTokens.contentSpacing
            ) {
                ForEach(viewModel.filteredChannels) { item in
                    ChannelCard(item: item, imageLoader: imageLoader)
                }
            }
            .padding(24)
        }
        .navigationTitle(title)
        .overlay {
            if viewModel.filteredChannels.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    private func localizedName(for country: Country) -> String {
        Locale.current.localizedString(forRegionCode: country.code) ?? country.name
    }
}
