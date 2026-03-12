import Foundation

struct CourtWeather: Sendable {
    let temperatureF: Double
    let weatherCode: Int
    let windSpeedMph: Double
    let fetchedAt: Date

    var emoji: String {
        switch weatherCode {
        case 0: return "☀️"
        case 1, 2, 3: return "⛅"
        case 45, 48: return "🌫️"
        case 51, 53, 55, 61, 63, 65: return "🌧️"
        case 71, 73, 75, 77: return "🌨️"
        case 80, 81, 82: return "🌦️"
        case 95, 96, 99: return "⛈️"
        default: return "🌤️"
        }
    }

    var label: String {
        switch weatherCode {
        case 0, 1: return "Clear"
        case 2, 3: return "Partly Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 61, 63, 65: return "Rainy"
        case 71, 73, 75, 77: return "Snowy"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Partly Cloudy"
        }
    }

    var condition: String {
        if [95, 96, 99].contains(weatherCode) || [80, 81, 82].contains(weatherCode) {
            return "Might want to wait this one out"
        }
        if [71, 73, 75, 77].contains(weatherCode) {
            return "Might want to wait this one out"
        }
        if [61, 63, 65].contains(weatherCode) {
            return "Might want to wait this one out"
        }
        if [51, 53, 55].contains(weatherCode) {
            return "Bring a hoodie"
        }
        if temperatureF < 40 {
            return "Dress warm"
        }
        if temperatureF < 55 {
            return "Bring a hoodie"
        }
        if windSpeedMph > 20 {
            return "Bring a hoodie"
        }
        return "Good conditions"
    }

    var showWind: Bool { windSpeedMph > 15 }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 30 * 60
    }
}

@Observable
@MainActor
final class WeatherService {
    static let shared = WeatherService()

    private var cache: [String: CourtWeather] = [:]
    private var inFlight: [String: Task<CourtWeather?, Never>] = [:]

    var weather: [String: CourtWeather] = [:]

    private init() {}

    func fetch(courtId: String, lat: Double, lng: Double) {
        if let cached = cache[courtId], !cached.isStale {
            weather[courtId] = cached
            return
        }

        if inFlight[courtId] != nil { return }

        let task = Task { [weak self] () -> CourtWeather? in
            defer { Task { @MainActor in self?.inFlight.removeValue(forKey: courtId) } }

            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lng)&current=temperature_2m,weathercode,windspeed_10m&temperature_unit=fahrenheit"
            guard let url = URL(string: urlString) else { return nil }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let result = CourtWeather(
                    temperatureF: response.current.temperature_2m,
                    weatherCode: response.current.weathercode,
                    windSpeedMph: response.current.windspeed_10m,
                    fetchedAt: Date()
                )
                await MainActor.run {
                    self?.cache[courtId] = result
                    self?.weather[courtId] = result
                }
                return result
            } catch {
                return nil
            }
        }

        inFlight[courtId] = task
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable {
        let temperature_2m: Double
        let weathercode: Int
        let windspeed_10m: Double
    }
}
