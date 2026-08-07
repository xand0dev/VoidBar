import Foundation
import Combine

struct WeatherData: Codable {
    let temperature: Double
    let condition: Int
    let locationName: String?
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
            let weatherUrlString = "https://api.open-meteo.com/v1/forecast?latitude=\(ipResponse.latitude)&longitude=\(ipResponse.longitude)&current_weather=true"
            guard let weatherUrl = URL(string: weatherUrlString) else { return }
            
            let (weatherJsonData, _) = try await URLSession.shared.data(from: weatherUrl)
            
            struct MeteoResponse: Decodable {
                struct CurrentWeather: Decodable {
                    let temperature: Double
                    let weathercode: Int
                }
                let current_weather: CurrentWeather
            }
            let meteoResponse = try JSONDecoder().decode(MeteoResponse.self, from: weatherJsonData)
            
            self.weather = WeatherData(
                temperature: meteoResponse.current_weather.temperature,
                condition: meteoResponse.current_weather.weathercode,
                locationName: ipResponse.city
            )
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
