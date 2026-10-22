//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import JellyfinAPI
import SwiftUI

// TODO: selected icon
@MainActor
struct TabItem: Displayable, @MainActor Identifiable, @MainActor Hashable {

    let content: AnyView
    let displayTitle: String
    let id: String
    let systemImage: String

    init(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> some View
    ) {
        self.content = AnyView(content())
        self.id = id
        self.displayTitle = title
        self.systemImage = systemImage
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension TabItem {

    static var adminDashboard: TabItem {
        TabItem(
            id: "admin-dashboard",
            title: L10n.dashboard,
            systemImage: "server.rack"
        ) {
            #if os(iOS)
            AdminDashboardView()
            #else
            EmptyView()
            #endif
        }
    }

    static func contentGroup(
        provider: some ContentGroupProvider
    ) -> TabItem {
        TabItem(
            id: provider.id,
            title: provider.displayTitle,
            systemImage: "house.fill"
        ) {
            ContentGroupView(provider: provider)
        }
    }

    static func item(id: String, displayTitle: String) -> TabItem {
        let item = BaseItemDto(id: id, name: displayTitle)
        let provider = ItemContentGroupProvider(item: item)

        return TabItem(
            id: id,
            title: displayTitle,
            systemImage: item.systemImage
        ) {
            ItemView(provider: provider)
        }
    }

    static func library(
        title: String,
        systemName: String,
        filters: ItemFilterCollection
    ) -> TabItem {
        TabItem(
            id: "library-\(UUID().uuidString)",
            title: title,
            systemImage: systemName
        ) {
            PagingLibraryView(
                library: ItemLibrary(
                    parent: BaseItemDto(name: title),
                    staticFilters: filters
                )
            )
            .if(UIDevice.isTV) { view in
                view.toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    /// A TV show library tab resolved from the user's server libraries by name.
    /// `anime == true` picks the library whose name contains "anime";
    /// otherwise the first TV show library that does not.
    static func tvLibrary(
        title: String,
        systemName: String,
        anime: Bool
    ) -> TabItem {
        TabItem(
            id: anime ? "tv-library-anime" : "tv-library-series",
            title: title,
            systemImage: systemName
        ) {
            TVLibraryTabView(title: title, anime: anime)
                .if(UIDevice.isTV) { view in
                    view.toolbar(.hidden, for: .navigationBar)
                }
        }
    }

    static var media: TabItem {
        TabItem(
            id: "media",
            title: L10n.media,
            systemImage: "rectangle.stack.fill"
        ) {
            PagingLibraryView(library: UserViewLibrary())
                .if(UIDevice.isTV) { view in
                    view.toolbar(.hidden, for: .navigationBar)
                }
        }
    }

    static var liveTV: TabItem {
        TabItem(
            id: "live-tv",
            title: L10n.liveTV,
            systemImage: "play.tv"
        ) {
            LiveTVTabView()
        }
    }

    static var search: TabItem {
        TabItem(
            id: "search",
            title: L10n.search,
            systemImage: "magnifyingglass"
        ) {
            SearchView()
                .if(UIDevice.isTV) { view in
                    view.toolbar(.hidden, for: .navigationBar)
                }
        }
    }

    static var settings: TabItem {
        TabItem(
            id: "settings",
            title: L10n.settings,
            systemImage: "gearshape"
        ) {
            SettingsView()
        }
    }
}

/// Live TV tab root: opens on the channel list with a section picker on top
/// for the guide, recordings and schedule.
struct LiveTVTabView: View {

    private enum Section: CaseIterable, Hashable {
        case channels
        case guide
        case recordings
        case schedule

        var displayTitle: String {
            switch self {
            case .channels: L10n.channels
            case .guide: L10n.guide
            case .recordings: L10n.recordings
            case .schedule: L10n.schedule
            }
        }
    }

    @State
    private var selection: Section = .channels

    @ViewBuilder
    private var sectionContent: some View {
        switch selection {
        case .channels:
            PagingLibraryView(
                library: ItemLibrary(
                    parent: BaseItemDto(name: L10n.channels),
                    filters: .init(itemTypes: [.liveTvChannel])
                )
            )
        case .guide:
            EPGView()
        case .recordings:
            PagingLibraryView(library: RecordingsLibrary())
        case .schedule:
            PagingLibraryView(library: ScheduledRecordingsLibrary())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.liveTV, selection: $selection) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.displayTitle)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 80)
            .padding(.top, 40)
            .padding(.bottom, 12)

            sectionContent
                .id(selection)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Resolves a TV show library by name from the user's libraries and shows it.
struct TVLibraryTabView: View {

    private enum LoadState {
        case loading
        case library(BaseItemDto)
        case fallback
        case missing
    }

    @Injected(\.currentUserSession)
    private var userSession

    @State
    private var state: LoadState = .loading

    let title: String
    let anime: Bool

    private func load() async {
        guard let userSession else {
            state = .fallback
            return
        }

        do {
            let parameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
            let response = try await userSession.send(Paths.getUserViews(parameters: parameters))

            // Match by exact library name (case-insensitive), falling back to TV show libraries
            let views = response.value.items ?? []
            let wanted = anime ? "anime" : "series"
            let match = views.first { ($0.name ?? "").caseInsensitiveCompare(wanted) == .orderedSame }

            if let match {
                state = .library(match)
            } else {
                state = anime ? .missing : .fallback
            }
        } catch {
            state = anime ? .missing : .fallback
        }
    }

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await load() }
        case let .library(library):
            PagingLibraryView(library: ItemLibrary(parent: library, filters: .default))
        case .fallback:
            PagingLibraryView(
                library: ItemLibrary(
                    parent: BaseItemDto(name: title),
                    staticFilters: .init(itemTypes: [.series])
                )
            )
        case .missing:
            ContentUnavailableView(
                L10n.noResults.localizedCapitalized,
                systemImage: "rectangle.on.rectangle.slash"
            )
        }
    }
}
