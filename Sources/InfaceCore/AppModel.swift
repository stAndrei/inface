import AppKit
import Combine
import Foundation

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var authStatus: CalendarAuthStatus
    @Published public private(set) var events: [MeetingEvent] = []
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var hasCompletedInitialFetch = false
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
    public let eventsCache: EventsCaching

    public var calendar: CalendarAccessing { calendarRouter }

    private let schedulerHorizon: TimeInterval = 48 * 60 * 60
    private var wakeObserver: NSObjectProtocol?
    private var isObserving = false
    private var refreshTask: Task<Void, Never>?

    public init(
        calendarRouter: CalendarSourceRouter,
        scheduler: AlertScheduler = AlertScheduler(),
        linkDetector: MeetingLinkDetector = .shared,
        linkOpener: LinkOpening = WorkspaceLinkOpener(),
        eventsCache: EventsCaching = EventsCacheStore(),
        settings: AppSettings = AppSettingsStore.load(),
        selectedDay: Date = Date()
    ) {
        self.calendarRouter = calendarRouter
        self.scheduler = scheduler
        self.linkDetector = linkDetector
        self.linkOpener = linkOpener
        self.eventsCache = eventsCache
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
        loadCachedEvents()
    }

    public convenience init(
        calendar: CalendarAccessing,
        scheduler: AlertScheduler = AlertScheduler(),
        linkDetector: MeetingLinkDetector = .shared,
        linkOpener: LinkOpening = WorkspaceLinkOpener(),
        eventsCache: EventsCaching = EventsCacheStore(),
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
            eventsCache: eventsCache,
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

    /// True while the selected day has no meetings yet because a fetch is still in flight.
    public var isLoadingSelectedDay: Bool {
        guard authStatus == .authorized else { return false }
        guard selectedDayEvents.isEmpty else { return false }
        return isRefreshing || !hasCompletedInitialFetch
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
            refreshEventsInBackground()
        }
    }

    public func goToToday() {
        selectedDay = Calendar.current.startOfDay(for: Date())
        refreshEventsInBackground()
    }

    /// Instant UI update from cache + background network refresh (popover open).
    public func presentPopover() {
        selectedDay = Calendar.current.startOfDay(for: Date())
        authStatus = calendarRouter.authorizationStatus
        if authStatus == .authorized {
            loadCachedEvents()
            // Always refresh Exchange in background so notes/links catch up after GetItem fix.
            refreshEventsInBackground(forceImmediate: settings.calendarSource == .exchange)
        }
    }

    public func start() {
        restartObserving()
        authStatus = calendarRouter.authorizationStatus
        if authStatus == .authorized {
            loadCachedEvents()
            refreshEventsInBackground()
        }
        if wakeObserver == nil {
            wakeObserver = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduler.handleWake()
                    self?.refreshEventsInBackground()
                }
            }
        }
    }

    public func requestAccess() async {
        _ = await calendarRouter.requestAccess()
        authStatus = calendarRouter.authorizationStatus
        if authStatus == .authorized {
            refreshEventsInBackground()
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
            refreshEventsInBackground()
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
            hasCompletedInitialFetch = false
            isRefreshing = false
            eventsCache.clear(source: .exchange)
            lastError = nil
        } catch {
            lastError = EWSErrorLocalized.message(for: error)
        }
    }

    /// Synchronous reload kept for tests / manual «Обновить» when cache-first is not needed.
    public func reloadEvents() {
        refreshEventsInBackground(forceImmediate: true)
    }

    public func refreshEventsInBackground(forceImmediate: Bool = false) {
        authStatus = calendarRouter.authorizationStatus
        guard authStatus == .authorized else {
            events = []
            hasCompletedInitialFetch = false
            isRefreshing = false
            return
        }

        // EventKit / mocks are local — keep synchronous so UI and tests stay snappy.
        if settings.calendarSource != .exchange {
            do {
                let range = fetchRange()
                let fetched = try calendarRouter.fetchEvents(from: range.start, to: range.end)
                applyFetchedEvents(fetched)
                isRefreshing = false
            } catch {
                lastError = EWSErrorLocalized.message(for: error)
                isRefreshing = false
                hasCompletedInitialFetch = true
            }
            return
        }

        // Exchange: show cache immediately, refresh over the network in the background.
        if !forceImmediate || events.isEmpty {
            loadCachedEvents()
        }

        refreshTask?.cancel()
        isRefreshing = true
        let range = fetchRange()
        let exchange = calendarRouter.exchange
        refreshTask = Task { [weak self] in
            do {
                let fetched = try await exchange.fetchEventsAsync(from: range.start, to: range.end)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.applyFetchedEvents(fetched)
                    self.isRefreshing = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.lastError = EWSErrorLocalized.message(for: error)
                    self.authStatus = self.calendarRouter.authorizationStatus
                    self.isRefreshing = false
                    self.hasCompletedInitialFetch = true
                }
            }
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
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else if NSApp.responds(to: Selector(("showPreferencesWindow:"))) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    public func openExchangeSetup() {
        // Open settings first so UI appears immediately; source switch must not block on network.
        openSettings()
        if settings.calendarSource != .exchange {
            settings.calendarSource = .exchange
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
        return openLink(url)
    }

    /// Join from the fullscreen alert: open the meeting link and dismiss only if it opened.
    @discardableResult
    public func joinActiveAlert() -> Bool {
        guard let event = activeAlert else { return false }
        let joined = joinMeeting(for: event)
        if joined {
            dismissAlert()
        }
        return joined
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
            hasCompletedInitialFetch = false
            loadCachedEvents()
            // Don't block Settings UI when switching to Exchange without credentials.
            if authStatus == .authorized {
                refreshEventsInBackground()
            } else {
                events = []
                hasCompletedInitialFetch = false
                isRefreshing = false
            }
        }
    }

    private func loadCachedEvents() {
        guard authStatus == .authorized else { return }
        let cached = eventsCache.load(source: settings.calendarSource)
        if !cached.isEmpty {
            events = cached
            scheduler.updateEvents(cached.filter { $0.endDate > Date() })
        }
    }

    private func applyFetchedEvents(_ fetched: [MeetingEvent]) {
        events = fetched
        eventsCache.save(fetched, source: settings.calendarSource)
        scheduler.updateEvents(fetched.filter { $0.endDate > Date() })
        lastError = nil
        authStatus = calendarRouter.authorizationStatus
        hasCompletedInitialFetch = true
    }

    /// Drop stale Exchange cache that may lack Body/notes from older FindItem-only fetches.
    public func invalidateExchangeCache() {
        eventsCache.clear(source: .exchange)
    }

    private func fetchRange() -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let selectedStart = cal.startOfDay(for: selectedDay)
        let selectedEnd = cal.date(byAdding: .day, value: 1, to: selectedStart) ?? selectedStart.addingTimeInterval(24 * 3600)
        let todayStart = cal.startOfDay(for: now)
        let fetchStart = min(selectedStart, todayStart)
        let fetchEnd = max(selectedEnd, now.addingTimeInterval(schedulerHorizon))
        return (fetchStart, fetchEnd)
    }

    private func restartObserving() {
        if isObserving {
            calendarRouter.stopObservingChanges()
        }
        calendarRouter.startObservingChanges { [weak self] in
            Task { @MainActor in
                self?.refreshEventsInBackground()
            }
        }
        isObserving = true
    }
}
