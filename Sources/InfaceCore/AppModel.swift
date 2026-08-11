import AppKit
import Combine
import Foundation

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var authStatus: CalendarAuthStatus
    @Published public private(set) var events: [MeetingEvent] = []
    @Published public var selectedDay: Date
    @Published public var settings: AppSettings {
        didSet {
            scheduler.updateSettings(settings)
            applyCalendarSettings()
            AppSettingsStore.save(settings)
        }
    }
    @Published public var activeAlert: MeetingEvent?
    @Published public var lastError: String?
    @Published public var exchangeLoginInProgress = false

    public let calendarRouter: CalendarSourceRouter
    public let scheduler: AlertScheduler
    public let linkDetector: MeetingLinkDetector
    public let linkOpener: LinkOpening

    public var calendar: CalendarAccessing { calendarRouter }

    private let schedulerHorizon: TimeInterval = 48 * 60 * 60
    private var wakeObserver: NSObjectProtocol?
    private var isObserving = false

    public init(
        calendarRouter: CalendarSourceRouter,
        scheduler: AlertScheduler = AlertScheduler(),
        linkDetector: MeetingLinkDetector = .shared,
        linkOpener: LinkOpening = WorkspaceLinkOpener(),
        settings: AppSettings = AppSettingsStore.load(),
        selectedDay: Date = Date()
    ) {
        self.calendarRouter = calendarRouter
        self.scheduler = scheduler
        self.linkDetector = linkDetector
        self.linkOpener = linkOpener
        self.settings = settings
        self.authStatus = calendarRouter.authorizationStatus
        self.selectedDay = Calendar.current.startOfDay(for: selectedDay)
        self.scheduler.updateSettings(settings)
        self.scheduler.onFire = { [weak self] event in
            Task { @MainActor in
                self?.activeAlert = event
            }
        }
        applyCalendarSettings(initial: true)
    }

    public convenience init(
        calendar: CalendarAccessing,
        scheduler: AlertScheduler = AlertScheduler(),
        linkDetector: MeetingLinkDetector = .shared,
        linkOpener: LinkOpening = WorkspaceLinkOpener(),
        settings: AppSettings = AppSettingsStore.load(),
        selectedDay: Date = Date()
    ) {
        let router: CalendarSourceRouter
        if let existing = calendar as? CalendarSourceRouter {
            router = existing
        } else {
            router = CalendarSourceRouter(
                source: settings.calendarSource,
                eventKit: calendar,
                exchange: EWSCalendarService()
            )
        }
        self.init(
            calendarRouter: router,
            scheduler: scheduler,
            linkDetector: linkDetector,
            linkOpener: linkOpener,
            settings: settings,
            selectedDay: selectedDay
        )
    }

    public var isSelectedDayToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }

    public var usesExchange: Bool {
        settings.calendarSource == .exchange
    }

    /// Meetings overlapping the currently selected day.
    public var selectedDayEvents: [MeetingEvent] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDay)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return events
        }
        return events
            .filter { $0.startDate < dayEnd && $0.endDate > dayStart }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Remaining meetings for today (alerts / compatibility).
    public var todaysRemainingEvents: [MeetingEvent] {
        let cal = Calendar.current
        let now = Date()
        let dayStart = cal.startOfDay(for: now)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return events
        }
        return events
            .filter { $0.startDate < dayEnd && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
    }

    public func shiftDay(by value: Int) {
        let cal = Calendar.current
        if let next = cal.date(byAdding: .day, value: value, to: selectedDay) {
            selectedDay = cal.startOfDay(for: next)
            reloadEvents()
        }
    }

    public func goToToday() {
        selectedDay = Calendar.current.startOfDay(for: Date())
        reloadEvents()
    }

    public func start() {
        restartObserving()
        authStatus = calendarRouter.authorizationStatus
        if authStatus == .authorized {
            reloadEvents()
        }
        if wakeObserver == nil {
            wakeObserver = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduler.handleWake()
                    self?.reloadEvents()
                }
            }
        }
    }

    public func requestAccess() async {
        _ = await calendarRouter.requestAccess()
        authStatus = calendarRouter.authorizationStatus
        if authStatus == .authorized {
            reloadEvents()
        }
    }

    public func exchangeLogin(username: String, password: String) async {
        exchangeLoginInProgress = true
        lastError = nil
        defer { exchangeLoginInProgress = false }
        do {
            try await calendarRouter.exchange.login(
                username: username,
                password: password,
                endpoint: settings.exchangeEndpoint
            )
            settings.exchangeUsername = username
            authStatus = calendarRouter.authorizationStatus
            reloadEvents()
        } catch {
            authStatus = calendarRouter.authorizationStatus
            lastError = EWSErrorLocalized.message(for: error)
        }
    }

    public func exchangeLogout() {
        do {
            try calendarRouter.exchange.logout()
            authStatus = calendarRouter.authorizationStatus
            events = []
            lastError = nil
        } catch {
            lastError = EWSErrorLocalized.message(for: error)
        }
    }

    public func reloadEvents() {
        authStatus = calendarRouter.authorizationStatus
        guard authStatus == .authorized else {
            events = []
            return
        }
        let cal = Calendar.current
        let now = Date()
        let selectedStart = cal.startOfDay(for: selectedDay)
        let selectedEnd = cal.date(byAdding: .day, value: 1, to: selectedStart) ?? selectedStart.addingTimeInterval(24 * 3600)
        let todayStart = cal.startOfDay(for: now)
        let fetchStart = min(selectedStart, todayStart)
        let fetchEnd = max(selectedEnd, now.addingTimeInterval(schedulerHorizon))
        do {
            events = try calendarRouter.fetchEvents(from: fetchStart, to: fetchEnd)
            scheduler.updateEvents(events.filter { $0.endDate > now })
            lastError = nil
        } catch {
            lastError = EWSErrorLocalized.message(for: error)
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

    public func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        return openLink(url)
    }

    public func openLink(_ url: URL) -> Bool {
        linkOpener.open(linkDetector.launchURL(for: url))
    }

    public func togglePause() {
        settings.alertsPaused.toggle()
    }

    public func forceAlert(_ event: MeetingEvent) {
        activeAlert = event
    }

    private func applyCalendarSettings(initial: Bool = false) {
        calendarRouter.setSource(settings.calendarSource)
        calendarRouter.configureExchange(
            endpoint: settings.exchangeEndpoint,
            username: settings.exchangeUsername
        )
        authStatus = calendarRouter.authorizationStatus
        if !initial {
            restartObserving()
            reloadEvents()
        }
    }

    private func restartObserving() {
        if isObserving {
            calendarRouter.stopObservingChanges()
        }
        calendarRouter.startObservingChanges { [weak self] in
            Task { @MainActor in
                self?.reloadEvents()
            }
        }
        isObserving = true
    }
}
