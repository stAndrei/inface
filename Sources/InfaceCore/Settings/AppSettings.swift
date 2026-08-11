import Foundation

public struct AppSettings: Equatable, Sendable, Codable {
    public var alertLeadTime: TimeInterval
    public var alertsPaused: Bool
    public var calendarSource: CalendarSource
    public var exchangeEndpoint: String
    public var exchangeUsername: String

    public static let `default` = AppSettings(
        alertLeadTime: 60,
        alertsPaused: false,
        calendarSource: .eventKit,
        exchangeEndpoint: AppSettings.defaultExchangeEndpoint,
        exchangeUsername: ""
    )

    public init(
        alertLeadTime: TimeInterval = 60,
        alertsPaused: Bool = false,
        calendarSource: CalendarSource = .eventKit,
        exchangeEndpoint: String = AppSettings.defaultExchangeEndpoint,
        exchangeUsername: String = ""
    ) {
        self.alertLeadTime = alertLeadTime
        self.alertsPaused = alertsPaused
        self.calendarSource = calendarSource
        self.exchangeEndpoint = exchangeEndpoint
        self.exchangeUsername = exchangeUsername
    }
}

public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}

public struct FixedClock: Clock {
    private let date: Date
    public init(_ date: Date) { self.date = date }
    public func now() -> Date { date }
}

public enum AppSettingsStore {
    private static let key = "ru.inface.appSettings"

    public static func load() -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    public static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
