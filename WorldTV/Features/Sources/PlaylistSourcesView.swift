import SwiftUI

struct PlaylistSourcesView: View {
    let loadSources: LoadPlaylistSourcesUseCase
    let addSource: AddPlaylistSourceUseCase
    let removeSource: RemovePlaylistSourceUseCase

    @State private var sources: [PlaylistSource] = []
    @State private var name = ""
    @State private var url = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            #if os(tvOS)
            TVScreenHeader("sources.title", systemImage: "list.bullet.rectangle")
                .listRowBackground(Color.clear)
            #endif

            Section("sources.addSection") {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("sources.namePlaceholder", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("sources.urlPlaceholder", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await add() }
                    } label: {
                        Label("sources.addButton", systemImage: "plus.circle.fill")
                    }
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                    #if os(tvOS)
                    .frame(minHeight: 54)
                    .worldTVCardButtonStyle()
                    #endif
                }
                #if os(tvOS)
                .padding(.vertical, 8)
                #endif
            }

            Section("sources.listSection") {
                if sources.isEmpty {
                    Text("sources.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            #if os(tvOS)
                            HStack {
                                sourceDetails(source)
                                Spacer()
                                Button("sources.delete", role: .destructive) {
                                    Task { await remove(source) }
                                }
                                .frame(minHeight: 54)
                            }
                            #else
                            sourceDetails(source)
                                .swipeActions {
                                    Button("sources.delete", role: .destructive) {
                                        Task { await remove(source) }
                                    }
                                }
                            #endif
                        }
                    }
                }
            }

            Section {
                Text("sources.disclaimer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            if isWorking { ProgressView() }
        }
        .platformNavigationTitle("sources.title")
        #if os(tvOS)
        .tvShelfBehavior()
        #endif
        .task { await reload() }
    }

    private func reload() async {
        do { sources = try await loadSources.execute() }
        catch { errorMessage = error.localizedDescription }
    }

    private func add() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await addSource.execute(name: name, urlString: url)
            name = ""
            url = ""
            errorMessage = nil
            await reload()
            NotificationCenter.default.post(name: .playlistSourcesDidChange, object: nil)
        } catch { errorMessage = error.localizedDescription }
    }

    private func remove(_ source: PlaylistSource) async {
        do {
            try await removeSource.execute(id: source.id)
            await reload()
            NotificationCenter.default.post(name: .playlistSourcesDidChange, object: nil)
        } catch { errorMessage = error.localizedDescription }
    }

    private func sourceDetails(_ source: PlaylistSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source.name)
                .font(.headline)
            Text(source.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

extension Notification.Name {
    static let playlistSourcesDidChange = Notification.Name("WorldTV.playlistSourcesDidChange")
}
