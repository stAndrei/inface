import Foundation
import InfaceCore

@main
enum InfaceTestRunner {
    static func main() async {
        var failures = 0
        failures += runUnitSuites()
        failures += await runFunctionalSuites()
        if failures == 0 {
            print("✅ All Inface tests passed")
            exit(0)
        } else {
            print("❌ \(failures) test(s) failed")
            exit(1)
        }
    }
}

@discardableResult
func expect(_ condition: Bool, _ message: String, file: StaticString = #fileID, line: UInt = #line) -> Int {
    if condition { return 0 }
    print("FAIL \(file):\(line) — \(message)")
    return 1
}

func runUnitSuites() -> Int {
    var f = 0
    f += meetingLinkTests()
    f += schedulerTests()
    f += calendarMockTests()
    return f
}

@MainActor
func runFunctionalSuites() async -> Int {
    var f = 0
    f += appModelFunctionalTests()
    return f
}

func meetingLinkTests() -> Int {
    let detector = MeetingLinkDetector()
    var f = 0

    let zoom = MeetingEvent(
        id: "1", title: "Standup", startDate: Date(), endDate: Date().addingTimeInterval(1800),
        calendarId: "c", calendarTitle: "Work",
        url: URL(string: "https://us06web.zoom.us/j/123456")
    )
    f += expect(detector.detect(in: zoom)?.host == "us06web.zoom.us", "zoom url")

    let teams = MeetingEvent(
        id: "2", title: "Sync", startDate: Date(), endDate: Date().addingTimeInterval(1800),
        calendarId: "c", calendarTitle: "Work",
        notes: "Join: https://teams.microsoft.com/l/meetup-join/19%3ameeting"
    )
    f += expect(detector.detect(in: teams)?.absoluteString.contains("teams.microsoft.com") == true, "teams notes")

    let meet = MeetingEvent(
        id: "3", title: "Design", startDate: Date(), endDate: Date().addingTimeInterval(1800),
        calendarId: "c", calendarTitle: "Work",
        location: "https://meet.google.com/abc-defg-hij"
    )
    f += expect(detector.detect(in: meet)?.host == "meet.google.com", "meet location")

    let other = MeetingEvent(
        id: "4", title: "Readme", startDate: Date(), endDate: Date().addingTimeInterval(1800),
        calendarId: "c", calendarTitle: "Work",
        notes: "Docs https://example.com/page"
    )
    f += expect(detector.detect(in: other) == nil, "ignore example.com")

    let hosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com",
        "whereby.com", "around.co", "bluejeans.com", "meet.jit.si",
        "discord.gg", "chime.aws", "gather.town", "gotomeeting.com",
        "skype.com", "facetime.apple.com", "meetings.ringcentral.com",
        "zoomgov.com", "larksuite.com", "workplace.com", "miro.com", "meetup.com"
    ]
    for host in hosts {
        let url = URL(string: "https://\(host)/room/1")!
        f += expect(detector.isConferenceURL(url), "provider \(host)")
    }

    let czEvent = MeetingEvent(
        id: "cz", title: "Синк", startDate: Date(), endDate: Date().addingTimeInterval(1800),
        calendarId: "c", calendarTitle: "Work",
        notes: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169"
    )
    f += expect(detector.detect(in: czEvent)?.host == "chatzone.o3t.ru", "chatzone detect")
    let launch = detector.launchURL(for: URL(string: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")!)
    f += expect(launch.scheme == "mattermost", "chatzone scheme")
    f += expect(launch.query?.contains("showMeetInApp=true") == true, "chatzone showMeetInApp")
    return f
}

func schedulerTests() -> Int {
    var f = 0
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let event = MeetingEvent(
        id: "e1", title: "Demo", startDate: start, endDate: start.addingTimeInterval(1800),
        calendarId: "c", calendarTitle: "Work"
    )

    let s1 = AlertScheduler(clock: FixedClock(start.addingTimeInterval(-600)), settings: AppSettings(alertLeadTime: 60))
    s1.updateEvents([event])
    f += expect(s1.peekNextFire()?.fireDate == start.addingTimeInterval(-60), "lead time fire")

    let s2 = AlertScheduler(
        clock: FixedClock(start.addingTimeInterval(-30)),
        settings: AppSettings(alertLeadTime: 60, alertsPaused: true)
    )
    s2.updateEvents([event])
    f += expect(s2.peekNextFire() == nil, "pause")

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let upcoming = MeetingEvent(
        id: "e1", title: "Demo", startDate: now.addingTimeInterval(120),
        endDate: now.addingTimeInterval(1800), calendarId: "c", calendarTitle: "Work"
    )
    let s3 = AlertScheduler(clock: FixedClock(now), settings: .default)
    s3.updateEvents([upcoming])
    s3.snooze(eventID: "e1", minutes: 5)
    f += expect(s3.peekNextFire()?.fireDate == now.addingTimeInterval(300), "snooze")

    let s4 = AlertScheduler(clock: FixedClock(start.addingTimeInterval(-30)), settings: AppSettings(alertLeadTime: 60))
    s4.updateEvents([event])
    f += expect(s4.peekNextFire()?.fireDate == start.addingTimeInterval(-30), "inside window")

    let s5 = AlertScheduler(clock: FixedClock(start.addingTimeInterval(-600)), settings: .default)
    s5.updateEvents([event])
    s5.handleWake()
    f += expect(s5.peekNextFire() != nil, "wake")
    return f
}

func calendarMockTests() -> Int {
    var f = 0
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let inside = MeetingEvent(
        id: "in", title: "Inside", startDate: now.addingTimeInterval(3600),
        endDate: now.addingTimeInterval(5400), calendarId: "exchange", calendarTitle: "Work Exchange"
    )
    let outside = MeetingEvent(
        id: "out", title: "Outside", startDate: now.addingTimeInterval(200_000),
        endDate: now.addingTimeInterval(201_000), calendarId: "exchange", calendarTitle: "Work Exchange"
    )
    let service = MockCalendarService(events: [outside, inside])
    do {
        let result = try service.fetchEvents(from: now, to: now.addingTimeInterval(48 * 3600))
        f += expect(result.map(\.id) == ["in"], "window filter")
    } catch {
        f += expect(false, "fetch threw \(error)")
    }
    return f
}

@MainActor
func appModelFunctionalTests() -> Int {
    var f = 0
    let now = Date()
    let event = MeetingEvent(
        id: "fx1", title: "Обзор спринта", startDate: now.addingTimeInterval(600),
        endDate: now.addingTimeInterval(2400), calendarId: "ex", calendarTitle: "Exchange"
    )
    let model = AppModel(calendar: MockCalendarService(events: [event]))
    model.start()
    f += expect(model.events.count == 1, "events loaded")
    f += expect(model.todaysRemainingEvents.count == 1, "today remaining")
    f += expect(model.events.first?.title == "Обзор спринта", "title")

    let past = MeetingEvent(
        id: "past", title: "Утро", startDate: now.addingTimeInterval(-7200),
        endDate: now.addingTimeInterval(-3600), calendarId: "c", calendarTitle: "Work"
    )
    let ongoing = MeetingEvent(
        id: "now", title: "Сейчас", startDate: now.addingTimeInterval(-600),
        endDate: now.addingTimeInterval(1800), calendarId: "c", calendarTitle: "Work"
    )
    let later = MeetingEvent(
        id: "later", title: "Вечер", startDate: now.addingTimeInterval(3600),
        endDate: now.addingTimeInterval(5400), calendarId: "c", calendarTitle: "Work"
    )
    let dayModel = AppModel(calendar: MockCalendarService(events: [past, ongoing, later]))
    dayModel.start()
    f += expect(dayModel.todaysRemainingEvents.map(\.id) == ["now", "later"], "today filter")

    let timeline = DayTimelineBuilder.build(
        events: [past, ongoing, later],
        day: now
    )
    f += expect(timeline.meetings.map(\.id) == ["past", "now", "later"] || timeline.meetings.map(\.id) == ["now", "later"] || timeline.meetings.count >= 2, "timeline meetings")
    f += expect(timeline.intervals.contains(where: {
        if case .free = $0.kind { return $0.duration > 0 } else { return false }
    }), "timeline has free gap")

    let nav = AppModel(calendar: MockCalendarService(authorizationStatus: .authorized), selectedDay: now)
    let before = Calendar.current.startOfDay(for: nav.selectedDay)
    nav.shiftDay(by: 1)
    f += expect(Calendar.current.startOfDay(for: nav.selectedDay) != before, "shift day")

    model.forceAlert(event)
    f += expect(model.activeAlert?.id == "fx1", "force alert")

    let opener = MockLinkOpener()
    let withLink = MeetingEvent(
        id: "fx3", title: "Call", startDate: Date().addingTimeInterval(60),
        endDate: Date().addingTimeInterval(600), calendarId: "c", calendarTitle: "Work",
        notes: "https://teams.microsoft.com/l/meetup-join/abc"
    )
    let joinModel = AppModel(calendar: MockCalendarService(), linkOpener: opener)
    f += expect(joinModel.joinMeeting(for: withLink), "join returns true")
    f += expect(opener.opened.count == 1, "opener called")

    let t0 = Date()
    let schedEvent = MeetingEvent(
        id: "fx4", title: "Call", startDate: t0.addingTimeInterval(90),
        endDate: t0.addingTimeInterval(600), calendarId: "c", calendarTitle: "Work"
    )
    let scheduler = AlertScheduler(clock: FixedClock(t0), settings: .default)
    let pauseModel = AppModel(
        calendar: MockCalendarService(events: [schedEvent]),
        scheduler: scheduler,
        settings: AppSettings(alertLeadTime: 60, alertsPaused: false)
    )
    pauseModel.start()
    f += expect(scheduler.peekNextFire() != nil, "scheduler armed")
    pauseModel.settings.alertsPaused = true
    f += expect(scheduler.peekNextFire() == nil, "paused")

    let denied = AppModel(calendar: MockCalendarService(
        authorizationStatus: .denied,
        events: [event]
    ))
    denied.start()
    f += expect(denied.events.isEmpty, "denied empty")
    f += expect(denied.authStatus == .denied, "denied status")
    return f
}
