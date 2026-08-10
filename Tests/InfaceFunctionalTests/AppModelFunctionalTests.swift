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

    func testJoinChatZoneUsesDeepLink() {
        let opener = MockLinkOpener()
        let event = MeetingEvent(
            id: "cz",
            title: "ChatZone",
            startDate: Date().addingTimeInterval(60),
            endDate: Date().addingTimeInterval(600),
            calendarId: "c",
            calendarTitle: "Work",
            notes: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169"
        )
        let model = AppModel(calendar: MockCalendarService(), linkOpener: opener)
        XCTAssertTrue(model.joinMeeting(for: event))
        XCTAssertEqual(opener.opened.first?.scheme, "mattermost")
        XCTAssertEqual(opener.opened.first?.host, "chatzone.o3t.ru")
        XCTAssertTrue(opener.opened.first?.query?.contains("showMeetInApp=true") == true)
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
