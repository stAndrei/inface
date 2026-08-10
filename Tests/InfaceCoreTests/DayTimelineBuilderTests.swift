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

        let timeline = DayTimelineBuilder.build(events: [a, b], day: day, now: now, calendar: calendar)
        XCTAssertEqual(timeline.meetings.map(\.id), ["a", "b"])

        let kinds = timeline.intervals.map { interval -> String in
            switch interval.kind {
            case .free: return "free"
            case .meeting(let e): return "m:\(e.id)"
            }
        }
        // Visible starts at 08:00 workday → free 8-10, A, free 11-13, B, free to midnight
        XCTAssertEqual(kinds, ["free", "m:a", "free", "m:b", "free"])
        XCTAssertEqual(timeline.intervals[0].duration, 2 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(timeline.intervals[2].duration, 2 * 60 * 60, accuracy: 0.1)
    }

    func testOtherDayIncludesFullSchedule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 12))!
        let meeting = MeetingEvent(
            id: "m",
            title: "Tomorrow",
            startDate: calendar.date(byAdding: .hour, value: 9, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 10, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )
        let timeline = DayTimelineBuilder.build(events: [meeting], day: day, now: now, calendar: calendar)
        XCTAssertFalse(timeline.isToday)
        XCTAssertEqual(timeline.meetings.map(\.id), ["m"])
    }
}

@MainActor
final class DayNavigationTests: XCTestCase {
    func testShiftDayChangesSelection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 0))!
        let model = AppModel(
            calendar: MockCalendarService(authorizationStatus: .authorized),
            selectedDay: day
        )
        model.shiftDay(by: 1)
        XCTAssertEqual(Calendar.current.startOfDay(for: model.selectedDay), calendar.date(byAdding: .day, value: 1, to: day)!)
        model.goToToday()
        XCTAssertTrue(Calendar.current.isDateInToday(model.selectedDay))
    }
}
