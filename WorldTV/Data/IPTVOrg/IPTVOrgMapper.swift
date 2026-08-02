import Foundation

struct IPTVOrgMapper: Sendable {
    func map(_ payload: IPTVOrgCatalogPayload) -> Catalog {
        let blockedChannelIDs = Set(payload.blocklist.map(\.channel))
        let channels = payload.channels
            .filter { !$0.isNSFW }
            .filter { $0.closed == nil }
            .filter { !blockedChannelIDs.contains($0.id) }
            .map(mapChannel)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let validChannelIDs = Set(channels.map(\.id))
        let streams = payload.streams.compactMap { mapStream($0, validChannelIDs: validChannelIDs) }
        let logos = payload.logos.compactMap { mapLogo($0, validChannelIDs: validChannelIDs) }
        let feeds = payload.feeds
            .compactMap { mapFeed($0, validChannelIDs: validChannelIDs) }
            .sorted {
                if $0.isMain != $1.isMain {
                    return $0.isMain
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }
        let blocklist = payload.blocklist.map(mapBlocklistEntry)

        return Catalog(
            channels: channels,
            countries: payload.countries.map(mapCountry).sorted { $0.name < $1.name },
            categories: payload.categories.map(mapCategory).sorted { $0.name < $1.name },
            streamsByChannelID: Dictionary(grouping: streams, by: \.channelID),
            logosByChannelID: Dictionary(grouping: logos, by: \.channelID),
            feeds: feeds,
            languages: payload.languages.map(mapLanguage).sorted { $0.name < $1.name },
            blocklist: blocklist
        )
    }

    private func mapChannel(_ dto: IPTVOrgChannelDTO) -> Channel {
        Channel(
            id: dto.id,
            name: dto.name,
            alternativeNames: dto.alternativeNames,
            countryCode: dto.country,
            categoryIDs: dto.categories,
            isNSFW: dto.isNSFW,
            network: dto.network,
            owners: dto.owners
        )
    }

    private func mapStream(
        _ dto: IPTVOrgStreamDTO,
        validChannelIDs: Set<String>
    ) -> ChannelStream? {
        guard
            let channelID = dto.channel,
            validChannelIDs.contains(channelID),
            let url = secureStreamURL(from: dto.url)
        else {
            return nil
        }

        return ChannelStream(
            id: url,
            channelID: channelID,
            url: url,
            feed: dto.feed,
            title: dto.title,
            quality: dto.quality,
            label: dto.label,
            referrer: dto.referrer,
            userAgent: dto.userAgent
        )
    }

    private func mapLogo(
        _ dto: IPTVOrgLogoDTO,
        validChannelIDs: Set<String>
    ) -> ChannelLogo? {
        guard
            let channelID = dto.channel,
            validChannelIDs.contains(channelID),
            let url = secureLogoURL(from: dto.url)
        else {
            return nil
        }

        return ChannelLogo(
            id: url,
            channelID: channelID,
            url: url,
            feed: dto.feed,
            width: dto.width,
            height: dto.height,
            format: dto.format,
            isInUse: dto.isInUse,
            tags: dto.tags
        )
    }

    private func mapFeed(
        _ dto: IPTVOrgFeedDTO,
        validChannelIDs: Set<String>
    ) -> ChannelFeed? {
        guard
            let channelID = dto.channel,
            validChannelIDs.contains(channelID)
        else {
            return nil
        }

        return ChannelFeed(
            id: dto.id,
            channelID: channelID,
            name: dto.name,
            isMain: dto.isMain == true,
            languages: dto.languages
        )
    }

    private func mapLanguage(_ dto: IPTVOrgLanguageDTO) -> Language {
        Language(code: dto.code, name: dto.name)
    }

    private func mapCountry(_ dto: IPTVOrgCountryDTO) -> Country {
        Country(code: dto.code, name: dto.name, languageCodes: dto.languages, flag: dto.flag)
    }

    private func mapCategory(_ dto: IPTVOrgCategoryDTO) -> ChannelCategory {
        ChannelCategory(id: dto.id, name: dto.name, description: dto.description)
    }

    private func mapBlocklistEntry(_ dto: IPTVOrgBlocklistDTO) -> BlocklistEntry {
        BlocklistEntry(channelID: dto.channel, reason: dto.reason, ref: dto.ref)
    }

    private func secureStreamURL(from value: String) -> URL? {
        guard
            let url = URL(string: value),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host != nil
        else {
            return nil
        }
        return url
    }

    private func secureLogoURL(from value: String) -> URL? {
        guard
            let url = URL(string: value),
            url.scheme?.lowercased() == "https",
            url.host != nil
        else {
            return nil
        }
        return url
    }
}
