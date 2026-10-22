//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Current time (always 24 hour) shown in the top trailing corner.
struct ClockOverlay: View {

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(Self.formatter.string(from: context.date))
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
        }
        // Right corner, outside the safe area, level with the tab bar
        .padding(.top, 78)
        .padding(.trailing, 30)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
