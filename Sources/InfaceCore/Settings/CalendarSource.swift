import Foundation

public enum CalendarSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case eventKit
    case exchange

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .eventKit: return "Системный (EventKit)"
        case .exchange: return "Exchange (EWS)"
        }
    }
}

public extension AppSettings {
    static let defaultExchangeEndpoint = "https://mailsec.o3t.ru/EWS/Exchange.asmx"
}
