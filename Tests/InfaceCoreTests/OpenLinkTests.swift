import XCTest
@testable import InfaceCore

final class OpenLinkTests: XCTestCase {
    @MainActor
    func testOpenLinkRewritesChatZone() {
        let opener = MockLinkOpener()
        let model = AppModel(calendar: MockCalendarService(), linkOpener: opener)
        let url = URL(string: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")!
        XCTAssertTrue(model.openLink(url))
        XCTAssertEqual(opener.opened.first?.scheme, "mattermost")
        XCTAssertTrue(opener.opened.first?.query?.contains("showMeetInApp=true") == true)
    }
}
