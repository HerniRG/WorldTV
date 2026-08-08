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
    @State private var pendingRemoval: PlaylistSource?

    var body: some View {
        Form {
            #if os(tvOS)
            TVScreenHeader("sources.title", systemImage: "list.bullet.rectangle")
                .listRowBackground(Color.clear)
            #endif

            Section("sources.addSection") {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("sources.namePlaceholder", text: $name)
                        #if os(iOS) || os(tvOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        #if os(tvOS)
                        .modifier(SourcesFieldFocusModifier())
                        #endif
                    TextField("sources.urlPlaceholder", text: $url)
                        #if os(iOS) || os(tvOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        #if os(tvOS)
                        .modifier(SourcesFieldFocusModifier())
                        #endif
                    Button {
                        Task { await add() }
                    } label: {
                        Label("sources.addButton", systemImage: "plus.circle.fill")
                    }
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                    .buttonStyle(.borderedProminent)
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
                                    pendingRemoval = source
                                }
                                .frame(minHeight: 54)
                                .buttonStyle(SourcesFocusButtonStyle(isDestructive: true))
                            }
                            #elseif os(macOS)
                            HStack(spacing: 12) {
                                sourceDetails(source)
                                Spacer(minLength: 12)
                                Button("sources.delete", systemImage: "trash", role: .destructive) {
                                    pendingRemoval = source
                                }
                                .labelStyle(.iconOnly)
                                .help("sources.delete")
                            }
                            #else
                            sourceDetails(source)
                                .swipeActions {
                                    Button("sources.delete", role: .destructive) {
                                        pendingRemoval = source
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
        #if os(macOS)
        // macOS lays out Form labels in a separate leading column. Keep that
        // column inside the window so longer localized labels are not clipped.
        .padding(.horizontal, 24)
        #endif
        .platformNavigationTitle("sources.title")
        #if os(tvOS)
        .tvShelfBehavior()
        #endif
        .task { await reload() }
        .confirmationDialog(
            "sources.delete.confirm.title",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { source in
            Button("settings.confirm.delete", role: .destructive) {
                Task { await remove(source) }
            }
            Button("action.cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: { source in
            Text("sources.delete.confirm.message \(source.name)")
        }
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

#if os(tvOS)
private struct SourcesFieldFocusModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .foregroundStyle(isFocused ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color.accentColor.opacity(0.28) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 3)
            }
    }
}

private struct SourcesFocusButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        FocusedButton(configuration: configuration, isDestructive: isDestructive)
    }

    private struct FocusedButton: View {
        let configuration: Configuration
        let isDestructive: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Color.white : Color.primary)
                .padding(.horizontal, 18)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isFocused
                                ? (isDestructive ? Color.red : Color.accentColor)
                                : Color.clear
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.white.opacity(0.9) : Color.clear, lineWidth: 3)
                }
                .opacity(configuration.isPressed ? 0.75 : 1)
        }
    }
}
#endif

extension Notification.Name {
    static let playlistSourcesDidChange = Notification.Name("WorldTV.playlistSourcesDidChange")
}
