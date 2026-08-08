import Foundation
import Combine

struct HourlyWeather: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let condition: Int
}

struct WeatherData {
    let temperature: Double
    let condition: Int
    let locationName: String?
    let hourly: [HourlyWeather]
}

@MainActor
final class WeatherStore: ObservableObject {
    @Published var weather: WeatherData?
    @Published var error: String?

    private var timer: Timer?

    func start() {
        stop()
        // Poll every 30 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchWeather()
            }
        }
        Task {
            await fetchWeather()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchWeather() async {
        do {
            // Get location via IP
            guard let locationUrl = URL(string: "https://ipapi.co/json/") else { return }
            let (locationData, _) = try await URLSession.shared.data(from: locationUrl)
            
            struct IPResponse: Decodable {
                let latitude: Double
                let longitude: Double
                let city: String
            }
            let ipResponse = try JSONDecoder().decode(IPResponse.self, from: locationData)
            
            // Get weather from Open-Meteo
            let weatherUrlString = "https://api.open-meteo.com/v1/forecast?latitude=\(ipResponse.latitude)&longitude=\(ipResponse.longitude)&current_weather=true&hourly=temperature_2m,weathercode&timezone=auto"
            guard let weatherUrl = URL(string: weatherUrlString) else { return }
            
            let (weatherJsonData, _) = try await URLSession.shared.data(from: weatherUrl)
            
            struct MeteoResponse: Decodable {
                struct CurrentWeather: Decodable {
                    let temperature: Double
                    let weathercode: Int
                }
                struct HourlyData: Decodable {
                    let time: [String]
                    let temperature_2m: [Double]
                    let weathercode: [Int]
                }
                let current_weather: CurrentWeather
                let hourly: HourlyData?
            }
            let meteoResponse = try JSONDecoder().decode(MeteoResponse.self, from: weatherJsonData)
            
            var hourlyForecast: [HourlyWeather] = []
            if let hourly = meteoResponse.hourly {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
                // Open-Meteo timezone=auto returns format like "2023-08-07T12:00" without Z.
                // We will use a simpler formatter.
                let simpleFormatter = DateFormatter()
                simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                
                let now = Date()
                for i in 0..<min(hourly.time.count, hourly.temperature_2m.count, hourly.weathercode.count) {
                    if let date = simpleFormatter.date(from: hourly.time[i]), date >= now.addingTimeInterval(-3600) {
                        hourlyForecast.append(HourlyWeather(time: date, temperature: hourly.temperature_2m[i], condition: hourly.weathercode[i]))
                        if hourlyForecast.count >= 24 { break } // Only next 24 hours
                    }
                }
            }
            
            self.weather = WeatherData(
                temperature: meteoResponse.current_weather.temperature,
                condition: meteoResponse.current_weather.weathercode,
                locationName: ipResponse.city,
                hourly: hourlyForecast
            )
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
