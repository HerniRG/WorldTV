import Foundation
import TVServices

final class TopShelfProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(
        completionHandler: @escaping (TVTopShelfContent?) -> Void
    ) {
        guard let payload = loadPayload() else {
            completionHandler(nil)
            return
        }

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        if !payload.favorites.isEmpty {
            sections.append(
                makeSection(
                    title: String(localized: "favorites.title"),
                    channels: payload.favorites
                )
            )
        }
        if !payload.recent.isEmpty {
            sections.append(
                makeSection(
                    title: String(localized: "home.recentlyWatched"),
                    channels: payload.recent
                )
            )
        }

        guard !sections.isEmpty else {
            completionHandler(nil)
            return
        }
        completionHandler(TVTopShelfSectionedContent(sections: sections))
    }

    private func makeSection(
        title: String,
        channels: [TopShelfChannel]
    ) -> TVTopShelfItemCollection<TVTopShelfSectionedItem> {
        let collection = TVTopShelfItemCollection(
            items: channels.map(makeItem)
        )
        collection.title = title
        return collection
    }

    private func makeItem(_ channel: TopShelfChannel) -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: channel.id)
        item.title = channel.name
        // Top Shelf section rows are rendered as 16:9 tiles. Using the
        // platform's HDTV shape avoids HeadBoard dropping a row whose remote
        // artwork does not match the requested square layout.
        item.imageShape = .hdtv
        if let logoURL = channel.logoURL, let url = URL(string: logoURL) {
            item.setImageURL(url, for: [.screenScale1x, .screenScale2x])
        }
        if let encodedID = channel.id.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ),
        let url = URL(string: "worldtv://play/\(encodedID)")
        {
            let action = TVTopShelfAction(url: url)
            item.playAction = action
            item.displayAction = action
        }
        return item
    }

    private func loadPayload() -> TopShelfPayload? {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: TopShelfConfiguration.appGroupIdentifier
            )
        else {
            return nil
        }
        let directory = container.appendingPathComponent(
            TopShelfConfiguration.payloadDirectory,
            isDirectory: true
        )
        let url = directory.appendingPathComponent(
            TopShelfConfiguration.payloadFileName
        )
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(TopShelfPayload.self, from: data)
    }
}
