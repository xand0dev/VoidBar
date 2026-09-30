import SwiftUI

struct WeatherPane: View {
    @ObservedObject var weatherStore: WeatherStore

    var body: some View {
        Group {
            if let error = weatherStore.error {
                EmptyState(symbol: "exclamationmark.icloud", title: localized("Weather is unavailable"), message: error)
            } else if let weather = weatherStore.weather {
                HStack(spacing: 12) {
                    current(weather)
                    if !weather.hourly.isEmpty {
                        hourly(weather.hourly)
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func current(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let location = weather.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.system(size: 8, weight: .bold))
                    Text(location).font(Theme.captionEmphasis)
                }
                .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 4)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: WeatherSymbols.symbol(for: weather.condition))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 34))
                Text(String(format: "%.0f°", weather.temperature))
                    .font(Theme.numeral(44, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }
            Spacer(minLength: 4)
            Text(WeatherSymbols.name(for: weather.condition))
                .font(Theme.bodyEmphasis)
                .foregroundStyle(Theme.secondary)
            if let range = range(weather.hourly) {
                Text(range)
                    .font(Theme.numeral(10.5, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(width: 170, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .leading)
        .card(padding: 12)
    }

    /// Lowest and highest of the hours shown.
    private func range(_ hours: [HourlyWeather]) -> String? {
        let temps = hours.prefix(12).map(\.temperature)
        guard let low = temps.min(), let high = temps.max() else { return nil }
        return String(format: "↓ %.0f°   ↑ %.0f°", low, high)
    }

    private func hourly(_ hours: [HourlyWeather]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: localized("Next hours"))
            HStack(spacing: 0) {
                ForEach(Array(hours.prefix(8).enumerated()), id: \.element.id) { index, hour in
                    VStack(spacing: 7) {
                        Text(index == 0 ? localized("Now") : Self.hour.string(from: hour.time))
                            .font(Theme.captionEmphasis)
                            .foregroundStyle(index == 0 ? Theme.primary : Theme.tertiary)
                        Image(systemName: WeatherSymbols.symbol(for: hour.condition))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 15))
                            .frame(height: 18)
                        Text(String(format: "%.0f°", hour.temperature))
                            .font(Theme.numeral(12.5))
                            .foregroundStyle(Theme.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(index == 0 ? Theme.surfaceHover : .clear)
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
    }

    private static let hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.setLocalizedDateFormatFromTemplate("HH")
        return formatter
    }()
}

/// WMO weather codes as SF Symbols and words, shared by the pane and the
/// collapsed island.
enum WeatherSymbols {
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func name(for code: Int) -> String {
        switch code {
        case 0: return localized("Clear sky")
        case 1, 2: return localized("Partly cloudy")
        case 3: return localized("Cloudy")
        case 45, 48: return localized("Fog")
        case 51...57: return localized("Drizzle")
        case 61...67: return localized("Rain")
        case 71...77, 85, 86: return localized("Snow")
        case 80...82: return localized("Showers")
        case 95...99: return localized("Thunderstorm")
        default: return localized("Cloudy")
        }
    }
}
