//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// A slowly drifting nebula-like background built from the profile's accent color.
struct AccentNebulaBackground: View {

    let accent: Color

    private func point(_ base: Double, _ t: TimeInterval, speed: Double, phase: Double, amount: Double) -> Float {
        Float(base + amount * sin(t * speed + phase))
    }

    private func points(at t: TimeInterval) -> [SIMD2<Float>] {
        [
            [0, 0],
            [point(0.5, t, speed: 0.11, phase: 0.0, amount: 0.12), 0],
            [1, 0],

            [0, point(0.5, t, speed: 0.09, phase: 1.3, amount: 0.12)],
            [
                point(0.5, t, speed: 0.13, phase: 2.1, amount: 0.22),
                point(0.5, t, speed: 0.10, phase: 4.0, amount: 0.22),
            ],
            [1, point(0.5, t, speed: 0.08, phase: 5.2, amount: 0.12)],

            [0, 1],
            [point(0.5, t, speed: 0.12, phase: 3.3, amount: 0.12), 1],
            [1, 1],
        ]
    }

    private func colors(at t: TimeInterval) -> [Color] {
        // Brightness breathes slowly so the glow never looks static
        let pulse = 0.5 + 0.5 * sin(t * 0.18)

        let deep = accent.mix(with: .black, by: 0.9)
        let dim = accent.mix(with: .black, by: 0.72)
        let glow = accent.mix(with: .black, by: 0.5 - 0.15 * pulse)
        let haze = accent.mix(with: .purple, by: 0.45).mix(with: .black, by: 0.62)

        return [
            deep, dim, deep,
            haze, glow, dim,
            deep, haze, deep,
        ]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: points(at: t),
                colors: colors(at: t),
                smoothsColors: true
            )
        }
        .background(Color.black)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
