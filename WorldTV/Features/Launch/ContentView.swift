//
//  ContentView.swift
//  WorldTV
//
//  Created by Hernan Rodriguez on 28/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: LaunchViewModel

    init(loadCatalogSummary: LoadCatalogSummaryUseCase) {
        _viewModel = State(
            initialValue: LaunchViewModel(loadCatalogSummary: loadCatalogSummary)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .loaded(let summary):
                summaryView(summary)
            case .empty:
                ContentUnavailableView(
                    "launch.empty.title",
                    systemImage: "tv.slash",
                    description: Text("launch.empty.message")
                )
            case .failed:
                ContentUnavailableView {
                    Label("launch.error.title", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("launch.error.message")
                } actions: {
                    Button("action.retry") {
                        viewModel.retry()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("app.name")
                .font(.largeTitle.bold())
            ProgressView("launch.loading")
        }
        .padding()
    }

    private func summaryView(_ summary: CatalogSummary) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("app.name")
                    .font(.largeTitle.bold())
                Text("launch.ready")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                metric(
                    value: summary.countryCount,
                    title: "launch.metric.countries",
                    systemImage: "flag"
                )
                metric(
                    value: summary.channelCount,
                    title: "launch.metric.channels",
                    systemImage: "tv"
                )
                metric(
                    value: summary.playableChannelCount,
                    title: "launch.metric.playable",
                    systemImage: "play.rectangle"
                )
            }
        }
        .padding(32)
    }

    private func metric(
        value: Int,
        title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(value, format: .number)
                .font(.title.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 140, maxWidth: 220)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
