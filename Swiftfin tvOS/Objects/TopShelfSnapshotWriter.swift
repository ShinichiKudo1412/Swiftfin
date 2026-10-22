//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import Foundation
import JellyfinAPI
import TVServices

/// Writes the recently added titles (text + backdrop images) into the shared App Group
/// container so the Top Shelf extension can show them on the Apple TV home screen.
enum TopShelfSnapshotWriter {

    private struct Snapshot: Encodable {

        struct Entry: Encodable {
            let id: String
            let title: String
            let summary: String?
            let imageFile: String
            let url: String
        }

        let items: [Entry]
    }

    private static let appGroupID = "group.com.romangalvez.swiftfin"
    private static let itemLimit = 10

    @MainActor
    static func refresh() async {
        // tvOS only allows writing inside Library/Caches of the group container
        guard let session = Container.shared.currentUserSession(),
              let directory = FileManager.default
              .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
              .appendingPathComponent("Library/Caches/TopShelf", isDirectory: true)
        else { return }

        do {
            var parameters = Paths.GetItemsParameters()
            parameters.userID = session.user.id
            parameters.includeItemTypes = [.movie, .series]
            parameters.isRecursive = true
            parameters.sortBy = [.dateCreated]
            parameters.sortOrder = [.descending]
            parameters.limit = itemLimit * 2
            parameters.fields = [.overview]
            parameters.enableImageTypes = [.backdrop]

            let response = try await session.client.send(Paths.getItems(parameters: parameters))


            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            var entries: [Snapshot.Entry] = []

            for item in response.value.items ?? [] {
                guard entries.count < itemLimit,
                      let id = item.id,
                      let title = item.name,
                      let tag = item.backdropImageTags?.first,
                      let imageURL = session.client.url(
                          with: Paths.getItemImage(
                              itemID: id,
                              imageType: ImageType.backdrop.rawValue,
                              parameters: .init(maxWidth: 1920, quality: 85, tag: tag)
                          )
                      )
                else {
                    continue
                }

                var request = URLRequest(url: imageURL)
                request.setValue(session.user.accessToken, forHTTPHeaderField: "X-Emby-Token")

                guard let (data, urlResponse) = try? await URLSession.shared.data(for: request),
                      (urlResponse as? HTTPURLResponse)?.statusCode == 200
                else {
                    continue
                }

                let fileName = "\(id)-\(tag).jpg"
                try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)

                entries.append(
                    .init(
                        id: id,
                        title: title,
                        summary: item.overview,
                        imageFile: fileName,
                        url: "swiftfin://\(session.server.id)/\(session.user.id)/item/\(id)"
                    )
                )
            }

            let snapshotData = try JSONEncoder().encode(Snapshot(items: entries))
            try snapshotData.write(to: directory.appendingPathComponent("snapshot.json"), options: .atomic)

            // Drop images that are no longer referenced
            let keep = Set(entries.map(\.imageFile) + ["snapshot.json"])
            let existing = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for file in existing where !keep.contains(file) {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
            }

            TVTopShelfContentProvider.topShelfContentDidChange()
        } catch {
            // Top Shelf is best effort and must never affect the app
        }
    }
}
