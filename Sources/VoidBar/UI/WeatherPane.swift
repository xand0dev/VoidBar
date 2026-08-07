import SwiftUI

struct WeatherPane: View {
    @ObservedObject var weatherStore: WeatherStore

    var body: some View {
        VStack(spacing: 8) {
            if let error = weatherStore.error {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
            } else if let weather = weatherStore.weather {
                Image(systemName: icon(for: weather.condition))
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
                
                Text(String(format: "%.1f°", weather.temperature))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                
                if let location = weather.locationName {
                    Text(location)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
                
                if !weather.hourly.isEmpty {
                    Spacer(minLength: 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(weather.hourly) { hour in
                                hourlyItem(hour)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 60)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }
    
    private func icon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67: return "cloud.drizzle.fill"
        case 71...77: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
    
    private func hourlyItem(_ hour: HourlyWeather) -> some View {
        VStack(spacing: 4) {
            Text(hour.time, format: .dateTime.hour())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Image(systemName: icon(for: hour.condition))
                .font(.system(size: 14))
                .foregroundStyle(.white)
            Text(String(format: "%.0f°", hour.temperature))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
