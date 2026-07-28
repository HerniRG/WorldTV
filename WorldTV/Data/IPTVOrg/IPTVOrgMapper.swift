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

        return Catalog(
            channels: channels,
            countries: payload.countries.map(mapCountry).sorted { $0.name < $1.name },
            categories: payload.categories.map(mapCategory).sorted { $0.name < $1.name },
            streamsByChannelID: Dictionary(grouping: streams, by: \.channelID),
            logosByChannelID: Dictionary(grouping: logos, by: \.channelID)
        )
    }

    private func mapChannel(_ dto: IPTVOrgChannelDTO) -> Channel {
        Channel(
            id: dto.id,
            name: dto.name,
            alternativeNames: dto.alternativeNames,
            countryCode: dto.country,
            categoryIDs: dto.categories,
            isNSFW: dto.isNSFW
        )
    }

    private func mapStream(
        _ dto: IPTVOrgStreamDTO,
        validChannelIDs: Set<String>
    ) -> ChannelStream? {
        guard
            let channelID = dto.channel,
            validChannelIDs.contains(channelID),
            let url = secureURL(from: dto.url)
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
            let url = secureURL(from: dto.url)
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
            isInUse: dto.isInUse
        )
    }

    private func mapCountry(_ dto: IPTVOrgCountryDTO) -> Country {
        Country(code: dto.code, name: dto.name, languageCodes: dto.languages, flag: dto.flag)
    }

    private func mapCategory(_ dto: IPTVOrgCategoryDTO) -> ChannelCategory {
        ChannelCategory(id: dto.id, name: dto.name)
    }

    private func secureURL(from value: String) -> URL? {
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
