import AppKit
import Combine
import Foundation

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var authStatus: CalendarAuthStatus
    @Published public private(set) var events: [MeetingEvent] = []
    @Published public var settings: AppSettings {
        didSet { scheduler.updateSettings(settings) }
    }
    @Published public var activeAlert: MeetingEvent?
    @Published public var lastError: String?

    public let calendar: CalendarAccessing
    public let scheduler: AlertScheduler
    public let linkDetector: MeetingLinkDetector
    public let linkOpener: LinkOpening

    private let horizon: TimeInterval = 48 * 60 * 60
    private var wakeObserver: NSObjectProtocol?

    public init(
        calendar: CalendarAccessing,
        scheduler: AlertScheduler = AlertScheduler(),
        linkDetector: MeetingLinkDetector = .shared,
        linkOpener: LinkOpening = WorkspaceLinkOpener(),
        settings: AppSettings = .default
    ) {
        self.calendar = calendar
        self.scheduler = scheduler
        self.linkDetector = linkDetector
        self.linkOpener = linkOpener
        self.settings = settings
        self.authStatus = calendar.authorizationStatus
        self.scheduler.updateSettings(settings)
        self.scheduler.onFire = { [weak self] event in
            Task { @MainActor in
                self?.activeAlert = event
            }
        }
    }

    public func start() {
        authStatus = calendar.authorizationStatus
        calendar.startObservingChanges { [weak self] in
            Task { @MainActor in
                self?.reloadEvents()
            }
        }
        if authStatus == .authorized {
            reloadEvents()
        }
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduler.handleWake()
            }
        }
    }

    public func requestAccess() async {
        _ = await calendar.requestAccess()
        authStatus = calendar.authorizationStatus
        if authStatus == .authorized {
            reloadEvents()
        }
    }

    public func reloadEvents() {
        guard authStatus == .authorized else {
            events = []
            return
        }
        let start = Date()
        let end = start.addingTimeInterval(horizon)
        do {
            events = try calendar.fetchEvents(from: start, to: end)
            scheduler.updateEvents(events)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func openSystemCalendarPrivacy() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
        ]
        for string in candidates {
            if let url = URL(string: string), linkOpener.open(url) {
                return
            }
        }
    }

    public func dismissAlert() {
        if let id = activeAlert?.id {
            scheduler.dismiss(eventID: id)
        }
        activeAlert = nil
    }

    public func snoozeAlert(minutes: Int) {
        if let id = activeAlert?.id {
            scheduler.snooze(eventID: id, minutes: minutes)
        }
        activeAlert = nil
    }

    public func joinMeeting(for event: MeetingEvent) -> Bool {
        guard let url = linkDetector.detect(in: event) else { return false }
        return linkOpener.open(url)
    }

    public func togglePause() {
        settings.alertsPaused.toggle()
    }

    public func forceAlert(_ event: MeetingEvent) {
        activeAlert = event
    }
}
