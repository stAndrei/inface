import XCTest
@testable import InfaceCore

final class DayTimelineBuilderTests: XCTestCase {
    func testSpanIsFirstToLastMeetingWithoutTrailingFreeTime() {
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
        XCTAssertEqual(timeline.visibleStart, a.startDate)
        XCTAssertEqual(timeline.visibleEnd, b.endDate)
        XCTAssertEqual(timeline.intervals.count, 2)
        XCTAssertFalse(timeline.intervals.contains { interval in
            if case .meeting = interval.kind { return false }
            return true
        })
    }

    func testEmptyDayHasNoMeetings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 12))!
        let timeline = DayTimelineBuilder.build(events: [], day: day, now: now, calendar: calendar)
        XCTAssertTrue(timeline.meetings.isEmpty)
        XCTAssertTrue(timeline.intervals.isEmpty)
    }
}

@MainActor
final class DayNavigationTests: XCTestCase {
    func testShiftDayChangesSelection() {
        let model = AppModel(calendar: MockCalendarService(authorizationStatus: .authorized))
        let before = model.selectedDay
        model.shiftDay(by: 1)
        XCTAssertEqual(
            Calendar.current.dateComponents([.day], from: before, to: model.selectedDay).day,
            1
        )
        model.goToToday()
        XCTAssertTrue(model.isSelectedDayToday)
    }
}
