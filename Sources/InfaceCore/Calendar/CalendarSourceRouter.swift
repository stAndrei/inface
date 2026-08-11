import Foundation

public final class CalendarSourceRouter: CalendarAccessing, @unchecked Sendable {
    public let eventKit: CalendarAccessing
    public let exchange: EWSCalendarService
    private var source: CalendarSource

    public init(
        source: CalendarSource = .eventKit,
        eventKit: CalendarAccessing = EventKitCalendarService(),
        exchange: EWSCalendarService = EWSCalendarService()
    ) {
        self.source = source
        self.eventKit = eventKit
        self.exchange = exchange
    }

    public var activeSource: CalendarSource { source }

    public var authorizationStatus: CalendarAuthStatus {
        activeService.authorizationStatus
    }

    public func setSource(_ source: CalendarSource) {
        stopObservingChanges()
        self.source = source
    }

    public func configureExchange(endpoint: String, username: String) {
        exchange.configure(endpoint: endpoint, username: username)
    }

    public func requestAccess() async -> Bool {
        await activeService.requestAccess()
    }

    public func fetchEvents(from start: Date, to end: Date) throws -> [MeetingEvent] {
        try activeService.fetchEvents(from: start, to: end)
    }

    public func startObservingChanges(_ handler: @escaping @Sendable () -> Void) {
        activeService.startObservingChanges(handler)
    }

    public func stopObservingChanges() {
        eventKit.stopObservingChanges()
        exchange.stopObservingChanges()
    }

    private var activeService: CalendarAccessing {
        switch source {
        case .eventKit: return eventKit
        case .exchange: return exchange
        }
    }
}
