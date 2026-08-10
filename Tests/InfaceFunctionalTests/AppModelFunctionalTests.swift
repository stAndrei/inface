import XCTest
@testable import InfaceCore

@MainActor
final class AppModelFunctionalTests: XCTestCase {
    func testAuthorizedListJoinAndForceAlert() {
        let now = Date()
        let event = MeetingEvent(
            id: "fx1",
            title: "Обзор спринта",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(2400),
            calendarId: "ex",
            calendarTitle: "Exchange",
            notes: "https://teams.microsoft.com/l/meetup-join/abc"
        )
        let opener = MockLinkOpener()
        let model = AppModel(calendar: MockCalendarService(events: [event]), linkOpener: opener)
        model.start()
        XCTAssertEqual(model.events.first?.title, "Обзор спринта")
        XCTAssertTrue(model.joinMeeting(for: event))
        XCTAssertEqual(opener.opened.count, 1)
        model.forceAlert(event)
        XCTAssertEqual(model.activeAlert?.id, "fx1")
    }

    func testDeniedShowsNoEvents() {
        let model = AppModel(calendar: MockCalendarService(authorizationStatus: .denied, events: [
            MeetingEvent(
                id: "x",
                title: "Hidden",
                startDate: Date().addingTimeInterval(100),
                endDate: Date().addingTimeInterval(200),
                calendarId: "c",
                calendarTitle: "Work"
            )
        ]))
        model.start()
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertEqual(model.authStatus, .denied)
    }
}
