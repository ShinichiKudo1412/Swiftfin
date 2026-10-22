//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CoreLocation
import Foundation
import SwiftUI

/// Current weather for the device location, using Open-Meteo (no API key).
/// Location comes from CoreLocation, falling back to IP geolocation.
@MainActor
final class WeatherModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    struct Day: Identifiable {

        let id: String
        let weekday: String
        let symbol: String
        let high: Int
        let low: Int
    }

    struct Snapshot {

        let city: String
        let temperature: Int
        let feelsLike: Int
        let symbol: String
        let summary: String
        let days: [Day]
    }

    enum State {
        case loading
        case loaded(Snapshot)
        case failed
    }

    @Published
    private(set) var state: State = .loading

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var isRefreshing = false
    private var lastLoad: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Refresh

    func refreshIfStale(after interval: TimeInterval = 30 * 60) async {
        if let lastLoad, Date.now.timeIntervalSince(lastLoad) < interval, case .loaded = state { return }

        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        if case .loaded = state {} else { state = .loading }

        guard let place = await locate() else {
            if case .loaded = state {} else { state = .failed }
            return
        }

        do {
            let snapshot = try await fetchWeather(for: place)
            state = .loaded(snapshot)
            lastLoad = .now
        } catch {
            if case .loaded = state {} else { state = .failed }
        }
    }

    // MARK: - Location

    private struct Place {

        let latitude: Double
        let longitude: Double
        let city: String
    }

    private func locate() async -> Place? {
        if let location = await currentLocation() {
            let city = await cityName(for: location)
            return Place(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                city: city ?? "Tu ubicación"
            )
        }

        return await ipLocation()
    }

    private func currentLocation() async -> CLLocation? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()

            // Wait for the answer to the system prompt
            for _ in 0 ..< 60 where manager.authorizationStatus == .notDetermined {
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                self.resumeLocation(nil)
            }
        }
    }

    private func resumeLocation(_ location: CLLocation?) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    private func cityName(for location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks?.first?.locality ?? placemarks?.first?.administrativeArea
    }

    private func ipLocation() async -> Place? {
        struct IPResponse: Decodable {
            let success: Bool?
            let city: String?
            let latitude: Double?
            let longitude: Double?
        }

        guard let url = URL(string: "https://ipwho.is/"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(IPResponse.self, from: data),
              response.success != false,
              let latitude = response.latitude,
              let longitude = response.longitude
        else { return nil }

        return Place(latitude: latitude, longitude: longitude, city: response.city ?? "Tu ubicación")
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.resumeLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumeLocation(nil)
        }
    }

    // MARK: - Weather

    private struct Response: Decodable {

        struct Current: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let is_day: Int
        }

        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
        }

        let current: Current
        let daily: Daily
    }

    private func fetchWeather(for place: Place) async throws -> Snapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(place.latitude)),
            .init(name: "longitude", value: String(place.longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "5"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(Response.self, from: data)

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")

        let weekday = DateFormatter()
        weekday.locale = Locale(identifier: "es")
        weekday.dateFormat = "EEE"

        let days: [Day] = response.daily.time.indices.compactMap { index in
            guard index < response.daily.weather_code.count,
                  index < response.daily.temperature_2m_max.count,
                  index < response.daily.temperature_2m_min.count
            else { return nil }

            let label: String
            if index == 0 {
                label = "Hoy"
            } else if let date = parser.date(from: response.daily.time[index]) {
                label = weekday.string(from: date).replacingOccurrences(of: ".", with: "").capitalized
            } else {
                label = response.daily.time[index]
            }

            return Day(
                id: response.daily.time[index],
                weekday: label,
                symbol: Self.symbol(for: response.daily.weather_code[index], isDay: true),
                high: Int(response.daily.temperature_2m_max[index].rounded()),
                low: Int(response.daily.temperature_2m_min[index].rounded())
            )
        }

        return Snapshot(
            city: place.city,
            temperature: Int(response.current.temperature_2m.rounded()),
            feelsLike: Int(response.current.apparent_temperature.rounded()),
            symbol: Self.symbol(for: response.current.weather_code, isDay: response.current.is_day == 1),
            summary: Self.summary(for: response.current.weather_code),
            days: days
        )
    }

    // MARK: - WMO weather codes

    private static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0:
            isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            "cloud.fill"
        case 45, 48:
            "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81:
            "cloud.rain.fill"
        case 65, 67, 82:
            "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86:
            "cloud.snow.fill"
        case 95, 96, 99:
            "cloud.bolt.rain.fill"
        default:
            "cloud.fill"
        }
    }

    private static func summary(for code: Int) -> String {
        switch code {
        case 0: "Despejado"
        case 1: "Mayormente despejado"
        case 2: "Parcialmente nublado"
        case 3: "Nublado"
        case 45, 48: "Niebla"
        case 51, 53, 55: "Llovizna"
        case 56, 57: "Llovizna helada"
        case 61, 63: "Lluvia"
        case 65: "Lluvia fuerte"
        case 66, 67: "Lluvia helada"
        case 71, 73, 75, 77: "Nieve"
        case 80, 81: "Chubascos"
        case 82: "Chubascos fuertes"
        case 85, 86: "Nevadas"
        case 95: "Tormenta"
        case 96, 99: "Tormenta con granizo"
        default: "Variable"
        }
    }
}
