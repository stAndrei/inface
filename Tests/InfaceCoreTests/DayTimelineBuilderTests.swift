import XCTest
@testable import InfaceCore

final class DayTimelineBuilderTests: XCTestCase {
    func testInsertsFreeGapsBetweenMeetings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 0))!
        let now = calendar.date(byAdding: .hour, value: 9, to: day)!

        let a = MeetingEvent(
            id: "a",
            title: "A",
            startDate: calendar.date(byAdding: .hour, value: 10, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 11, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )
        let b = MeetingEvent(
            id: "b",
            title: "B",
            startDate: calendar.date(byAdding: .hour, value: 13, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 14, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )

        let timeline = DayTimelineBuilder.build(events: [a, b], now: now, calendar: calendar)
        XCTAssertEqual(timeline.meetings.map(\.id), ["a", "b"])

        let kinds = timeline.intervals.map { interval -> String in
            switch interval.kind {
            case .free: return "free"
            case .meeting(let e): return "m:\(e.id)"
            }
        }
        XCTAssertEqual(kinds, ["free", "m:a", "free", "m:b", "free"])
        XCTAssertEqual(timeline.intervals[0].duration, 60 * 60, accuracy: 0.1)
        XCTAssertEqual(timeline.intervals[2].duration, 2 * 60 * 60, accuracy: 0.1)
    }

    func testExcludesPastMeetings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 0))!
        let now = calendar.date(byAdding: .hour, value: 12, to: day)!
        let past = MeetingEvent(
            id: "past",
            title: "Past",
            startDate: calendar.date(byAdding: .hour, value: 9, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 10, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )
        let timeline = DayTimelineBuilder.build(events: [past], now: now, calendar: calendar)
        XCTAssertTrue(timeline.meetings.isEmpty)
        XCTAssertEqual(timeline.intervals.count, 1)
        if case .free = timeline.intervals[0].kind {
            XCTAssertGreaterThan(timeline.intervals[0].duration, 0)
        } else {
            XCTFail("expected free interval")
        }
    }
}
