//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

@main
struct SwiftfinApp: App {

    init() {
        // Personal fork: always use Spanish regardless of the Apple TV system language.
        // Must run before any localized string is resolved.
        UserDefaults.standard.set(["es"], forKey: "AppleLanguages")

        Self.configure()

        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.label]
    }

    var body: some Scene {
        WindowGroup {
            OverlayToastView {
                WithLocalUserAuthentication {
                    RootView()
                }
            }
        }
    }
}
