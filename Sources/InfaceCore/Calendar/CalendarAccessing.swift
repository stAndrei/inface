import Foundation

public enum CalendarAuthStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public protocol CalendarAccessing: AnyObject {
    var authorizationStatus: CalendarAuthStatus { get }
    func requestAccess() async -> Bool
    func fetchEvents(from start: Date, to end: Date) throws -> [MeetingEvent]
    func startObservingChanges(_ handler: @escaping @Sendable () -> Void)
    func stopObservingChanges()
}
