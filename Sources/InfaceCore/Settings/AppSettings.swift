import Foundation

public struct AppSettings: Equatable, Sendable {
    public var alertLeadTime: TimeInterval
    public var alertsPaused: Bool

    public static let `default` = AppSettings(alertLeadTime: 60, alertsPaused: false)

    public init(alertLeadTime: TimeInterval = 60, alertsPaused: Bool = false) {
        self.alertLeadTime = alertLeadTime
        self.alertsPaused = alertsPaused
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
