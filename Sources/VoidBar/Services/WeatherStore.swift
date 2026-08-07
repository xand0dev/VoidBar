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
        // Fetch to be implemented
    }
}
