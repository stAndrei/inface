import XCTest
@testable import InfaceCore

@MainActor
final class ExchangeAppModelFunctionalTests: XCTestCase {
    func testExchangeNotConfiguredShowsEmpty() {
        let exchange = EWSCalendarService(credentialStore: MockExchangeCredentialStore())
        let router = CalendarSourceRouter(source: .exchange, exchange: exchange)
        var settings = AppSettings.default
        settings.calendarSource = .exchange
        let model = AppModel(calendarRouter: router, settings: settings)
        model.start()
        XCTAssertEqual(model.authStatus, .notDetermined)
        XCTAssertTrue(model.events.isEmpty)
    }

    func testExchangeSourceFlag() {
        var settings = AppSettings.default
        settings.calendarSource = .exchange
        let model = AppModel(
            calendarRouter: CalendarSourceRouter(source: .exchange),
            settings: settings
        )
        XCTAssertTrue(model.usesExchange)
    }
}
