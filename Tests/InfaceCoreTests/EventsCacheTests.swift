import XCTest
@testable import InfaceCore

final class EventsCacheStoreTests: XCTestCase {
    func testInMemoryRoundTrip() {
        let cache = InMemoryEventsCache()
        let event = MeetingEvent(
            id: "1",
            title: "Кеш",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: "ex",
            calendarTitle: "Exchange"
        )
        cache.save([event], source: .exchange)
        XCTAssertEqual(cache.load(source: .exchange).map(\.id), ["1"])
        cache.clear(source: .exchange)
        XCTAssertTrue(cache.load(source: .exchange).isEmpty)
    }
}

@MainActor
final class EventsCacheAppModelTests: XCTestCase {
    func testPresentPopoverShowsCacheImmediately() {
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
            eventsCache: cache,
            settings: .default
        )
        model.start()
        model.presentPopover()
        XCTAssertEqual(model.events.first?.id, "cached")
        XCTAssertEqual(model.events.first?.title, "Из кеша")
    }
}
