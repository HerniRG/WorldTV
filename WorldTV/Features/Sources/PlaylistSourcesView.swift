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
            TVScreenHeader("Sources", systemImage: "list.bullet.rectangle")
                .listRowBackground(Color.clear)
            #endif

            Section("Add playlist") {
                TextField("Name (optional)", text: $name)
                TextField("M3U or M3U8 URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await add() }
                } label: {
                    Label("Add source", systemImage: "plus.circle.fill")
                }
                .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            }

            Section("Your sources") {
                if sources.isEmpty {
                    Text("No sources added yet. Add a playlist URL to begin.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            #if os(tvOS)
                            HStack {
                                sourceDetails(source)
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    Task { await remove(source) }
                                }
                            }
                            #else
                            sourceDetails(source)
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        Task { await remove(source) }
                                    }
                                }
                            #endif
                        }
                    }
                }
            }

            Section {
                Text("WorldTV does not provide channels or playlists. Add only sources you are authorized to access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            if isWorking { ProgressView() }
        }
        .platformNavigationTitle("Sources")
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
            Text(source.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

extension Notification.Name {
    static let playlistSourcesDidChange = Notification.Name("WorldTV.playlistSourcesDidChange")
}
