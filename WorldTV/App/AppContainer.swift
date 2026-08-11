import Foundation

@MainActor
struct AppContainer {
    let loadHomeContent: LoadHomeContentUseCase
    let loadCountries: LoadCountriesUseCase
    let loadChannelsByCountry: LoadChannelsByCountryUseCase
    let loadCategories: LoadCategoriesUseCase
    let loadChannelsByCategory: LoadChannelsByCategoryUseCase
    let loadChannelDetail: LoadChannelDetailUseCase
    let loadChannelsByBroadcaster: LoadChannelsByBroadcasterUseCase
    let resolvePlaybackSources: ResolvePlayableStreamUseCase
    let recordRecentlyWatched: RecordRecentlyWatchedUseCase
    let loadFavoriteChannels: LoadFavoriteChannelsUseCase
    let searchChannels: SearchChannelsUseCase
    let favoritesStore: FavoritesStore
    let refreshCatalog: RefreshCatalogUseCase
    let clearRecentlyWatched: ClearRecentlyWatchedUseCase
    let clearCatalogCache: ClearCatalogCacheUseCase
    let loadCatalogCacheDate: LoadCatalogCacheDateUseCase
    let loadPlaylistSources: LoadPlaylistSourcesUseCase
    let restorePlaylistSources: RestorePlaylistSourcesUseCase
    let addPlaylistSource: AddPlaylistSourceUseCase
    let updatePlaylistSource: UpdatePlaylistSourceUseCase
    let removePlaylistSource: RemovePlaylistSourceUseCase
    let cloudSyncStore: CloudKitSyncStore
    let topShelfPayloadWriter: TopShelfPayloadWriter

    func synchronizePreferences() async {
        let defaults = UserDefaults.standard
        let local = CloudKitSyncStore.Preferences(
            autoplayChannels: defaults.object(forKey: "autoplayChannels") as? Bool ?? true,
            preferredQuality: defaults.string(forKey: "preferredQuality") ?? "automatic",
            showGeoBlockedChannels: defaults.object(forKey: "showGeoBlockedChannels") as? Bool ?? true,
            updatedAt: defaults.object(forKey: "WorldTV.preferencesUpdatedAt") as? Date ?? .now
        )
        do {
            if let remote = try await cloudSyncStore.loadPreferences(), remote.updatedAt > local.updatedAt {
                defaults.set(remote.autoplayChannels, forKey: "autoplayChannels")
                defaults.set(remote.preferredQuality, forKey: "preferredQuality")
                defaults.set(remote.showGeoBlockedChannels, forKey: "showGeoBlockedChannels")
                defaults.set(remote.updatedAt, forKey: "WorldTV.preferencesUpdatedAt")
            } else {
                try await cloudSyncStore.savePreferences(local)
                defaults.set(local.updatedAt, forKey: "WorldTV.preferencesUpdatedAt")
            }
        } catch {
            // Local preferences remain available without iCloud.
        }
    }

    static func live() -> AppContainer {
        let urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 128 * 1_024 * 1_024
        )
        URLCache.shared = urlCache

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = urlCache

        let httpClient = URLSessionHTTPClient(session: URLSession(configuration: configuration))
        let iptvOrgAPIClient = IPTVOrgAPIClient(httpClient: httpClient)
        let iptvOrgMapper = IPTVOrgMapper()
        let baseDirectory = Self.prepareStorageDirectory()
        let localSourceStore = FilePlaylistSourceStore(
            fileURL: baseDirectory
                .appendingPathComponent("playlist-sources.json")
        )
        let cloudStore = CloudKitSyncStore()
        let sourceStore = SyncedPlaylistSourceStore(local: localSourceStore, cloud: cloudStore)
        let metadataStore = FileCatalogMetadataStore(
            fileURL: baseDirectory
                .appendingPathComponent("catalog-metadata.json")
        )
        let repository = PlaylistCatalogRepository(
            sourceStore: sourceStore,
            httpClient: httpClient,
            specializedLoader: { source in
                guard
                    source.url.host?.lowercased() == "iptv-org.github.io",
                    source.url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() == "iptv/index.m3u"
                else {
                    return nil
                }
                let payload = try await iptvOrgAPIClient.fetchCatalog()
                return iptvOrgMapper.map(payload)
            }
        )
        let localRecentlyWatchedRepository = UserDefaultsRecentlyWatchedRepository()
        let recentlyWatchedRepository = SyncedRecentlyWatchedRepository(local: localRecentlyWatchedRepository, cloud: cloudStore)
        let localFavoritesRepository = UserDefaultsFavoritesRepository()
        let favoritesRepository = SyncedFavoritesRepository(
            local: localFavoritesRepository,
            cloud: cloudStore
        )
        let favoritesStore = FavoritesStore(
            loadFavorites: LoadFavoriteChannelIDsUseCase(repository: favoritesRepository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favoritesRepository),
            clearFavorites: ClearFavoritesUseCase(repository: favoritesRepository)
        )

        return AppContainer(
            loadHomeContent: LoadHomeContentUseCase(
                repository: repository,
                recentlyWatchedRepository: recentlyWatchedRepository,
                favoritesRepository: favoritesRepository
            ),
            loadCountries: LoadCountriesUseCase(repository: repository),
            loadChannelsByCountry: LoadChannelsByCountryUseCase(repository: repository),
            loadCategories: LoadCategoriesUseCase(repository: repository),
            loadChannelsByCategory: LoadChannelsByCategoryUseCase(repository: repository),
            loadChannelDetail: LoadChannelDetailUseCase(
                repository: repository
            ),
            loadChannelsByBroadcaster: LoadChannelsByBroadcasterUseCase(repository: repository),
            resolvePlaybackSources: ResolvePlayableStreamUseCase(repository: repository),
            recordRecentlyWatched: RecordRecentlyWatchedUseCase(
                repository: recentlyWatchedRepository
            ),
            loadFavoriteChannels: LoadFavoriteChannelsUseCase(
                channelRepository: repository,
                favoritesRepository: favoritesRepository
            ),
            searchChannels: SearchChannelsUseCase(
                channelRepository: repository,
                favoritesRepository: favoritesRepository
            ),
            favoritesStore: favoritesStore,
            refreshCatalog: RefreshCatalogUseCase(repository: repository, metadataStore: metadataStore),
            clearRecentlyWatched: ClearRecentlyWatchedUseCase(
                repository: recentlyWatchedRepository
            ),
            clearCatalogCache: ClearCatalogCacheUseCase(
                cache: metadataStore,
                invalidate: { await repository.invalidate() }
            ),
            loadCatalogCacheDate: LoadCatalogCacheDateUseCase(cache: metadataStore),
            loadPlaylistSources: LoadPlaylistSourcesUseCase(store: sourceStore),
            restorePlaylistSources: RestorePlaylistSourcesUseCase(store: sourceStore, cloud: cloudStore),
            addPlaylistSource: AddPlaylistSourceUseCase(
                store: sourceStore,
                invalidate: { await repository.invalidate() },
                validate: { source in
                    var request = URLRequest(url: source.url)
                    request.setValue("application/vnd.apple.mpegurl, audio/mpegurl, text/plain, */*", forHTTPHeaderField: "Accept")
                    request.setValue("WorldTV/1.0", forHTTPHeaderField: "User-Agent")
                    do {
                        let data = try await httpClient.data(for: request)
                        _ = try M3UPlaylistParser().parse(data, source: source)
                    } catch let error as PlaylistSourceError {
                        throw error
                    } catch {
                        throw PlaylistSourceError.unreachable
                    }
                }
            ),
            updatePlaylistSource: UpdatePlaylistSourceUseCase(
                store: sourceStore,
                invalidate: { await repository.invalidate() }
            ),
            removePlaylistSource: RemovePlaylistSourceUseCase(
                store: sourceStore,
                invalidate: { await repository.invalidate() }
            ),
            cloudSyncStore: cloudStore,
            topShelfPayloadWriter: TopShelfPayloadWriter(
                repository: repository,
                recentlyWatchedRepository: recentlyWatchedRepository,
                favoritesRepository: favoritesRepository
            )
        )
    }

    private static func prepareStorageDirectory() -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("WorldTV", isDirectory: true)
        let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("WorldTV", isDirectory: true)

        let applicationGroupDirectory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.hrgapps.WorldTV"
        )?.appendingPathComponent("WorldTV", isDirectory: true)

        let legacyDirectories = [applicationSupportDirectory, applicationGroupDirectory].compactMap { $0 }

        // Playlist sources belong to this app only. Keeping them in the app's
        // own container also works when a physical-device provisioning profile
        // does not include the optional App Group entitlement.
        for directory in [applicationGroupDirectory, documentsDirectory, applicationSupportDirectory].compactMap({ $0 }) {
            if ensureDirectoryIsWritable(directory, fileManager: fileManager) {
                migrateLegacyFiles(from: legacyDirectories, to: directory, fileManager: fileManager)
                return directory
            }
        }

        let temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent("WorldTV", isDirectory: true)
        _ = ensureDirectoryIsWritable(temporaryDirectory, fileManager: fileManager)
        return temporaryDirectory
    }

    @discardableResult
    private static func ensureDirectoryIsWritable(_ directory: URL, fileManager: FileManager) -> Bool {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let probe = directory.appendingPathComponent(".write-probe")
            try Data("probe".utf8).write(to: probe, options: .atomic)
            try fileManager.removeItem(at: probe)
            return true
        } catch {
            NSLog("WorldTV: directory is not writable (%@): %@", directory.path, error.localizedDescription)
            return false
        }
    }

    private static func migrateLegacyFiles(from legacyDirectories: [URL], to sharedDirectory: URL, fileManager: FileManager) {
        for filename in ["playlist-sources.json", "catalog-metadata.json"] {
            let sharedFile = sharedDirectory.appendingPathComponent(filename)
            guard !fileManager.fileExists(atPath: sharedFile.path) else { continue }

            for legacyDirectory in legacyDirectories {
                let legacyFile = legacyDirectory.appendingPathComponent(filename)
                guard fileManager.fileExists(atPath: legacyFile.path) else { continue }
                if (try? fileManager.copyItem(at: legacyFile, to: sharedFile)) != nil {
                    break
                }
            }
        }
    }
}
