//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import Foundation
import JellyfinAPI

struct DefaultContentGroupProvider: ContentGroupProvider {

    @Injected(\.currentUserSession)
    var userSession: UserSession?

    let displayTitle: String = L10n.home
    let id: String = "default-content-group-provider"

    func makeGroups(environment: Empty) async throws -> [any ContentGroup] {
        guard let userSession else { return [] }

        let parameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
        let userViewsPath = Paths.getUserViews(parameters: parameters)
        let userViews = try await userSession.send(userViewsPath)
        let excludedLibraryIDs = userSession.user.data.configuration?.latestItemsExcludes ?? []

        let resolvedUserViews = (userViews.value.items ?? [])
            .subtracting(excludedLibraryIDs, using: \.id)
            .intersecting(
                [
                    .homevideos,
                    .movies,
                    .musicvideos,
                    .tvshows,
                ],
                using: \.collectionType
            )

        return _makeGroups(userViews: resolvedUserViews)
    }

    @ContentGroupBuilder
    private func _makeGroups(userViews: [BaseItemDto]) -> [any ContentGroup] {

        #if os(tvOS)
        let cinematicSelectionContentGroup = CinematicSelectionContentGroup(
            resumeLibrary: ResumeItemsLibrary(mediaTypes: [.video]),
            recentlyAddedLibrary: RecentlyAddedLibrary()
        )

        cinematicSelectionContentGroup

        WeatherGroup()
        #else
        PosterGroup(
            library: ResumeItemsLibrary(mediaTypes: [.video]),
            posterDisplayType: .landscape,
            posterSize: .medium,
            _viewContext: .isInResume
        )
        #endif

        // Content is grouped by library folder (Movies, Series, Anime, ...) instead of
        // mixing everything into global "next up" / "recently added" rows.
        userViews
            .flatMap { view -> [any ContentGroup] in
                var groups: [any ContentGroup] = []

                if view.collectionType == .tvshows {
                    groups.append(
                        PosterGroup(
                            id: "next-up-\(view.id ?? "")",
                            library: NextUpLibrary(library: view),
                            posterDisplayType: .landscape
                        )
                    )
                }

                groups.append(
                    PosterGroup(
                        library: LatestInLibrary(library: view),
                        posterDisplayType: .landscape
                    )
                )

                return groups
            }
    }
}
