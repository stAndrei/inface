import Foundation

public final class MockCalendarService: CalendarAccessing, @unchecked Sendable {
    public var authorizationStatus: CalendarAuthStatus
    public var events: [MeetingEvent]
    public var requestAccessResult: Bool
    private var changeHandler: (@Sendable () -> Void)?

    public init(
        authorizationStatus: CalendarAuthStatus = .authorized,
        events: [MeetingEvent] = [],
        requestAccessResult: Bool = true
    ) {
        self.authorizationStatus = authorizationStatus
        self.events = events
        self.requestAccessResult = requestAccessResult
    }

    public func requestAccess() async -> Bool {
        authorizationStatus = requestAccessResult ? .authorized : .denied
        return requestAccessResult
    }

    public func fetchEvents(from start: Date, to end: Date) throws -> [MeetingEvent] {
        events.filter { $0.startDate < end && $0.endDate > start }
            .sorted { $0.startDate < $1.startDate }
    }

    public func startObservingChanges(_ handler: @escaping @Sendable () -> Void) {
        changeHandler = handler
    }

    public func stopObservingChanges() {
        changeHandler = nil
    }

    public func simulateStoreChange() {
        changeHandler?()
    }
}
