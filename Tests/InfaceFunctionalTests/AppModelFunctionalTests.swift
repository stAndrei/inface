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
        XCTAssertEqual(model.events.count, 1)
        XCTAssertEqual(model.todaysRemainingEvents.count, 1)
        XCTAssertEqual(model.events.first?.title, "Обзор спринта")
        XCTAssertTrue(model.joinMeeting(for: event))
        XCTAssertEqual(opener.opened.count, 1)
        model.forceAlert(event)
        XCTAssertEqual(model.activeAlert?.id, "fx1")
        XCTAssertTrue(model.joinActiveAlert())
        XCTAssertNil(model.activeAlert)
        XCTAssertEqual(opener.opened.count, 2)
    }

    func testJoinActiveAlertKeepsAlertWhenNoLink() {
        let event = MeetingEvent(
            id: "no-link",
            title: "Офлайн",
            startDate: Date().addingTimeInterval(60),
            endDate: Date().addingTimeInterval(600),
            calendarId: "c",
            calendarTitle: "Work"
        )
        let opener = MockLinkOpener()
        let model = AppModel(calendar: MockCalendarService(), linkOpener: opener)
        model.forceAlert(event)
        XCTAssertFalse(model.joinActiveAlert())
        XCTAssertEqual(model.activeAlert?.id, "no-link")
        XCTAssertTrue(opener.opened.isEmpty)
    }

    func testJoinActiveAlertOpensMeetzoneThenDismisses() {
        let opener = MockLinkOpener()
        let event = MeetingEvent(
            id: "cz-alert",
            title: "ChatZone",
            startDate: Date().addingTimeInterval(60),
            endDate: Date().addingTimeInterval(600),
            calendarId: "c",
            calendarTitle: "Work",
            notes: "https://chatzone.o3t.ru/meetzone/a9f671fd-4e31-4e2c-bd3f-c0e5a6fab0c8"
        )
        let model = AppModel(calendar: MockCalendarService(), linkOpener: opener)
        model.forceAlert(event)
        XCTAssertTrue(model.joinActiveAlert())
        XCTAssertNil(model.activeAlert)
        XCTAssertEqual(opener.opened.first?.path, "/meet/a9f671fd-4e31-4e2c-bd3f-c0e5a6fab0c8")
    }

    func testTodayListExcludesPastAndKeepsOngoing() {
        let now = Date()
        let past = MeetingEvent(
            id: "past",
            title: "Утро",
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            calendarId: "c",
            calendarTitle: "Work"
        )
        let ongoing = MeetingEvent(
            id: "now",
            title: "Сейчас",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work"
        )
        let later = MeetingEvent(
            id: "later",
            title: "Вечер",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(5400),
            calendarId: "c",
            calendarTitle: "Work"
        )
        let model = AppModel(calendar: MockCalendarService(events: [past, ongoing, later]))
        model.start()
        XCTAssertEqual(model.todaysRemainingEvents.map(\.id), ["now", "later"])
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

    func testJoinChatZoneMeetzonePathOpensMeetDeepLink() {
        let opener = MockLinkOpener()
        let event = MeetingEvent(
            id: "cz-meetzone",
            title: "ChatZone",
            startDate: Date().addingTimeInterval(60),
            endDate: Date().addingTimeInterval(600),
            calendarId: "c",
            calendarTitle: "Work",
            notes: "https://chatzone.o3t.ru/meetzone/a9f671fd-4e31-4e2c-bd3f-c0e5a6fab0c8"
        )
        let model = AppModel(calendar: MockCalendarService(), linkOpener: opener)
        XCTAssertTrue(model.joinMeeting(for: event))
        XCTAssertEqual(opener.opened.first?.scheme, "mattermost")
        XCTAssertEqual(opener.opened.first?.path, "/meet/a9f671fd-4e31-4e2c-bd3f-c0e5a6fab0c8")
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
        XCTAssertFalse(model.isLoadingSelectedDay)
    }

    func testShowsLoadingBeforeFirstFetchThenEmptyDay() {
        let model = AppModel(
            calendar: MockCalendarService(events: []),
            eventsCache: InMemoryEventsCache()
        )
        XCTAssertTrue(model.isLoadingSelectedDay)
        model.start()
        XCTAssertFalse(model.isLoadingSelectedDay)
        XCTAssertTrue(model.selectedDayEvents.isEmpty)
        XCTAssertTrue(model.hasCompletedInitialFetch)
    }

    func testDoesNotShowLoadingWhenCacheHasMeetings() {
        let cache = InMemoryEventsCache()
        let now = Date()
        let event = MeetingEvent(
            id: "cached",
            title: "Из кеша",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(2400),
            calendarId: "c",
            calendarTitle: "Work"
        )
        cache.save([event], source: .eventKit)
        let model = AppModel(
            calendar: MockCalendarService(events: [event]),
            eventsCache: cache
        )
        XCTAssertFalse(model.isLoadingSelectedDay)
        XCTAssertEqual(model.selectedDayEvents.map(\.id), ["cached"])
    }
}
