//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension SeriesEpisodeContentGroup {

    struct SeasonSelector: PlatformView {

        @Binding
        var selection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        @Router
        private var router

        let seasons: [PagingLibraryViewModel<EpisodeLibrary>]
        let preferredSelection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        private var selectedSeason: PagingLibraryViewModel<EpisodeLibrary>? {
            seasons.first { $0.id == selection }
        }

        private func openEpisodes(
            for season: PagingLibraryViewModel<EpisodeLibrary>
        ) {
            router.route(to: .library(library: season.library))
        }

        @ViewBuilder
        private func singleSeasonButton(
            _ season: PagingLibraryViewModel<EpisodeLibrary>
        ) -> some View {
            Button {
                openEpisodes(for: season)
            } label: {
                HStack(spacing: 3) {
                    Text(season.library.parent.displayTitle)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Image(systemName: "chevron.forward")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary, .secondary)
            .edgePadding(.horizontal)
            .accessibilityAction(named: Text(L10n.openLibrary)) {
                openEpisodes(for: season)
            }
        }

        var tvOSView: some View {
            // One menu instead of a chip per season: long series (30+ seasons) stay reachable
            HStack(spacing: 24) {
                Menu {
                    Picker(L10n.seasons, selection: $selection) {
                        ForEach(seasons) { season in
                            Text(season.library.parent.displayTitle)
                                .tag(season.id)
                        }
                    }
                } label: {
                    Label(
                        selectedSeason?.library.parent.displayTitle ?? L10n.seasons,
                        systemImage: "chevron.down"
                    )
                    .labelStyle(.titleAndIcon)
                }

                Button(L10n.allEpisodes, systemImage: "list.bullet") {
                    if let selectedSeason {
                        openEpisodes(for: selectedSeason)
                    }
                }
                .disabled(selectedSeason == nil)
            }
            .controlSize(.large)
            .edgePadding(.horizontal)
            .focusSection()
        }

        var iOSView: some View {
            if seasons.count == 1, let season = seasons.first {
                singleSeasonButton(season)
            } else {
                Menu(
                    selectedSeason?.library.parent.displayTitle ?? L10n.episodes,
                    systemImage: "chevron.down"
                ) {
                    Button(L10n.allEpisodes, systemImage: "list.bullet") {
                        if let selectedSeason {
                            openEpisodes(for: selectedSeason)
                        }
                    }
                    .disabled(selectedSeason == nil)

                    Divider()

                    Picker(L10n.seasons, selection: $selection) {
                        ForEach(seasons) { season in
                            Text(season.library.parent.displayTitle)
                                .tag(season.id)
                        }
                    }
                }
                .labelStyle(.trailingIcon)
                .buttonStyle(.capsule)
                .edgePadding(.horizontal)
            }
        }
    }
}
