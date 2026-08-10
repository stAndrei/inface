import Foundation

public struct ScheduledAlert: Equatable, Sendable {
    public let event: MeetingEvent
    public let fireDate: Date

    public init(event: MeetingEvent, fireDate: Date) {
        self.event = event
        self.fireDate = fireDate
    }
}

public final class AlertScheduler: @unchecked Sendable {
    private let clock: Clock
    private var settings: AppSettings
    private var events: [MeetingEvent] = []
    /// After fire/dismiss, suppress until this date (usually event end or snooze target).
    private var suppressUntil: [String: Date] = [:]
    private var timer: Timer?
    public private(set) var nextAlert: ScheduledAlert?
    public var onFire: ((MeetingEvent) -> Void)?

    public init(clock: Clock = SystemClock(), settings: AppSettings = .default) {
        self.clock = clock
        self.settings = settings
    }

    public func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        recompute()
    }

    public func updateEvents(_ events: [MeetingEvent]) {
        self.events = events
        recompute()
    }

    public func snooze(eventID: String, minutes: Int) {
        suppressUntil[eventID] = clock.now().addingTimeInterval(TimeInterval(minutes * 60))
        recompute()
    }

    public func dismiss(eventID: String) {
        if let event = events.first(where: { $0.id == eventID }) {
            suppressUntil[eventID] = event.endDate
        } else {
            suppressUntil[eventID] = clock.now().addingTimeInterval(24 * 3600)
        }
        recompute()
    }

    public func handleWake() {
        recompute()
    }

    public func recompute() {
        timer?.invalidate()
        timer = nil
        nextAlert = peekNextFire()
        guard let next = nextAlert else { return }
        let interval = max(next.fireDate.timeIntervalSince(clock.now()), 0.05)
        if Thread.isMainThread {
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.fireIfNeeded()
            }
        }
    }

    public func fireIfNeeded() {
        guard !settings.alertsPaused else { return }
        guard let next = peekNextFire() else { return }
        let now = clock.now()
        guard next.fireDate <= now.addingTimeInterval(0.5) else {
            recompute()
            return
        }
        suppressUntil[next.event.id] = next.event.endDate
        nextAlert = nil
        onFire?(next.event)
        recompute()
    }

    public func peekNextFire(now: Date? = nil) -> ScheduledAlert? {
        let now = now ?? clock.now()
        guard !settings.alertsPaused else { return nil }

        var candidates: [ScheduledAlert] = []
        for event in events {
            guard event.endDate > now else { continue }
            if let until = suppressUntil[event.id], until > now {
                // Snooze path: fire at suppressUntil if still before end
                if until < event.endDate {
                    candidates.append(ScheduledAlert(event: event, fireDate: until))
                }
                continue
            }
            let fire = event.startDate.addingTimeInterval(-settings.alertLeadTime)
            if fire > now {
                candidates.append(ScheduledAlert(event: event, fireDate: fire))
            } else if event.startDate > now {
                candidates.append(ScheduledAlert(event: event, fireDate: now))
            }
        }
        return candidates.min(by: { $0.fireDate < $1.fireDate })
    }
}
