//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Home section with the current weather and a 5 day forecast for the device location.
struct WeatherGroup: ContentGroup {

    let id = "weather"

    func body(with viewModel: Empty) -> some View {
        WeatherSection()
    }

    private struct WeatherSection: View {

        @StateObject
        private var model = WeatherModel()

        @ViewBuilder
        private func currentView(_ snapshot: WeatherModel.Snapshot) -> some View {
            HStack(spacing: 28) {
                Image(systemName: snapshot.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 84))

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.city)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(snapshot.temperature)°")
                        .font(.system(size: 72, weight: .semibold))

                    Text("\(snapshot.summary) · Sensación \(snapshot.feelsLike)°")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }

        @ViewBuilder
        private func forecastView(_ days: [WeatherModel.Day]) -> some View {
            HStack(spacing: 36) {
                ForEach(days) { day in
                    VStack(spacing: 10) {
                        Text(day.weekday)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Image(systemName: day.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.title2)

                        Text("\(day.high)°")
                            .font(.callout)
                            .fontWeight(.semibold)

                        Text("\(day.low)°")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        @ViewBuilder
        private var cardContent: some View {
            switch model.state {
            case .loading:
                HStack(spacing: 20) {
                    ProgressView()
                    Text("Consultando el clima…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)

            case .failed:
                Label("No se pudo obtener el clima. Presiona para reintentar.", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)

            case let .loaded(snapshot):
                HStack {
                    currentView(snapshot)

                    Spacer(minLength: 40)

                    forecastView(snapshot.days)
                }
                .padding(.vertical, 8)
            }
        }

        var body: some View {
            ContentGroupSection {
                Button {
                    Task { await model.refresh() }
                } label: {
                    cardContent
                        .padding(.horizontal, 36)
                        .padding(.vertical, 20)
                }
                .buttonStyle(.card)
                .edgePadding(.horizontal)
            } header: {
                Text("Clima")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .edgePadding(.horizontal)
            }
            .task {
                await model.refreshIfStale()
            }
        }
    }
}
