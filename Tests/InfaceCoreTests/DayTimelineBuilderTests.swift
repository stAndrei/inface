import XCTest
@testable import InfaceCore

final class DayTimelineBuilderTests: XCTestCase {
    func testSpanIsFirstToLastMeeting() {
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
        XCTAssertEqual(timeline.laidOutMeetings.count, 2)
        XCTAssertEqual(timeline.laidOutMeetings.map(\.columnCount), [1, 1])
    }

    func testOverlappingMeetingsGetSideBySideColumns() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 0))!
        let now = calendar.date(byAdding: .hour, value: 8, to: day)!

        let a = MeetingEvent(
            id: "a",
            title: "A",
            startDate: calendar.date(byAdding: .hour, value: 10, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 12, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )
        let b = MeetingEvent(
            id: "b",
            title: "B",
            startDate: calendar.date(byAdding: .hour, value: 11, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 13, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )
        let c = MeetingEvent(
            id: "c",
            title: "C",
            startDate: calendar.date(byAdding: .hour, value: 14, to: day)!,
            endDate: calendar.date(byAdding: .hour, value: 15, to: day)!,
            calendarId: "c",
            calendarTitle: "Work"
        )

        let laidOut = DayTimelineBuilder.layoutColumns(for: [a, b, c])
        let byId = Dictionary(uniqueKeysWithValues: laidOut.map { ($0.event.id, $0) })

        XCTAssertEqual(byId["a"]?.columnCount, 2)
        XCTAssertEqual(byId["b"]?.columnCount, 2)
        XCTAssertNotEqual(byId["a"]?.columnIndex, byId["b"]?.columnIndex)
        XCTAssertEqual(byId["c"]?.columnCount, 1)
        XCTAssertEqual(byId["c"]?.columnIndex, 0)
    }

    func testThreeWayOverlapUsesThreeColumns() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let a = MeetingEvent(id: "a", title: "A", startDate: base, endDate: base.addingTimeInterval(3600), calendarId: "c", calendarTitle: "W")
        let b = MeetingEvent(id: "b", title: "B", startDate: base.addingTimeInterval(600), endDate: base.addingTimeInterval(4200), calendarId: "c", calendarTitle: "W")
        let c = MeetingEvent(id: "c", title: "C", startDate: base.addingTimeInterval(1200), endDate: base.addingTimeInterval(4800), calendarId: "c", calendarTitle: "W")

        let laidOut = DayTimelineBuilder.layoutColumns(for: [a, b, c])
        XCTAssertEqual(Set(laidOut.map(\.columnIndex)).count, 3)
        XCTAssertTrue(laidOut.allSatisfy { $0.columnCount == 3 })
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
