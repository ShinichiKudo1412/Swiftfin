//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import TVServices

/// Top Shelf content: shows recently added titles from the snapshot the app writes
/// into the shared App Group container.
final class ContentProvider: TVTopShelfContentProvider {

    private struct Snapshot: Decodable {

        struct Entry: Decodable {
            let id: String
            let title: String
            let summary: String?
            let imageFile: String
            let url: String
        }

        let items: [Entry]
    }

    private static let appGroupID = "group.com.romangalvez.swiftfin"

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent("Library/Caches/TopShelf", isDirectory: true),
            let data = try? Data(contentsOf: container.appendingPathComponent("snapshot.json")),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
            snapshot.items.isNotEmpty
        else {
            completionHandler(nil)
            return
        }

        let items = snapshot.items.map { entry -> TVTopShelfCarouselItem in
            let item = TVTopShelfCarouselItem(identifier: entry.id)
            item.title = entry.title
            item.summary = entry.summary
            item.setImageURL(
                container.appendingPathComponent(entry.imageFile),
                for: [.screenScale1x, .screenScale2x]
            )

            if let url = URL(string: entry.url) {
                item.displayAction = TVTopShelfAction(url: url)
            }

            return item
        }

        completionHandler(TVTopShelfCarouselContent(style: .details, items: items))
    }
}

private extension Collection {

    var isNotEmpty: Bool { !isEmpty }
}
