import XCTest
@testable import InfaceCore

final class AlertSchedulerTests: XCTestCase {
    func testLeadTimeAndPauseAndSnooze() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let event = MeetingEvent(
            id: "e1",
            title: "Demo",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work"
        )

        let armed = AlertScheduler(clock: FixedClock(start.addingTimeInterval(-600)), settings: AppSettings(alertLeadTime: 60))
        armed.updateEvents([event])
        XCTAssertEqual(armed.peekNextFire()?.fireDate, start.addingTimeInterval(-60))

        let paused = AlertScheduler(
            clock: FixedClock(start.addingTimeInterval(-30)),
            settings: AppSettings(alertLeadTime: 60, alertsPaused: true)
        )
        paused.updateEvents([event])
        XCTAssertNil(paused.peekNextFire())

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let upcoming = MeetingEvent(
            id: "e1",
            title: "Demo",
            startDate: now.addingTimeInterval(120),
            endDate: now.addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work"
        )
        let snoozed = AlertScheduler(clock: FixedClock(now), settings: .default)
        snoozed.updateEvents([upcoming])
        snoozed.snooze(eventID: "e1", minutes: 5)
        XCTAssertEqual(snoozed.peekNextFire()?.fireDate, now.addingTimeInterval(300))
    }
}
