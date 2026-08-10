import EventKit
import Foundation

public final class EventKitCalendarService: CalendarAccessing {
    private let store: EKEventStore
    private var observer: NSObjectProtocol?

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    deinit {
        stopObservingChanges()
    }

    public var authorizationStatus: CalendarAuthStatus {
        Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    public func fetchEvents(from start: Date, to end: Date) throws -> [MeetingEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map(Self.mapEvent).sorted { $0.startDate < $1.startDate }
    }

    public func startObservingChanges(_ handler: @escaping @Sendable () -> Void) {
        stopObservingChanges()
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            handler()
        }
    }

    public func stopObservingChanges() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    public static func mapStatus(_ status: EKAuthorizationStatus) -> CalendarAuthStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess:
            return .authorized
        case .writeOnly:
            return .denied
        @unknown default:
            // Older SDKs used `.authorized` which maps to full read in practice.
            if status.rawValue == 3 { return .authorized }
            return .denied
        }
    }

    public static func mapEvent(_ event: EKEvent) -> MeetingEvent {
        MeetingEvent(
            id: event.calendarItemIdentifier,
            title: event.title ?? "Без названия",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarId: event.calendar?.calendarIdentifier ?? "",
            calendarTitle: event.calendar?.title ?? "",
            notes: event.notes,
            url: event.url,
            location: event.location
        )
    }
}
