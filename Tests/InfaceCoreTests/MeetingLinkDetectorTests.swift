import XCTest
@testable import InfaceCore

final class MeetingLinkDetectorTests: XCTestCase {
    private let detector = MeetingLinkDetector()

    func testDetectsZoomFromURL() {
        let event = MeetingEvent(
            id: "1",
            title: "Standup",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work",
            url: URL(string: "https://us06web.zoom.us/j/123456")
        )
        XCTAssertEqual(detector.detect(in: event)?.host, "us06web.zoom.us")
    }

    func testDetectsTeamsFromNotes() {
        let event = MeetingEvent(
            id: "2",
            title: "Sync",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work",
            notes: "Join: https://teams.microsoft.com/l/meetup-join/19%3ameeting"
        )
        XCTAssertTrue(detector.detect(in: event)!.absoluteString.contains("teams.microsoft.com"))
    }

    func testManyProviders() {
        let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "whereby.com"]
        for host in hosts {
            XCTAssertTrue(detector.isConferenceURL(URL(string: "https://\(host)/r")!), host)
        }
    }

    func testDetectsChatZoneMeetLink() {
        let event = MeetingEvent(
            id: "cz",
            title: "Синк",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work",
            notes: "Звонок https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169"
        )
        let url = detector.detect(in: event)
        XCTAssertEqual(url?.host, "chatzone.o3t.ru")
        XCTAssertTrue(url!.path.contains("6d54c167-7829-4d3e-80e8-3e0dd626b169"))
    }

    func testPrefersMeetUUIDInNotesOverExchangeURLField() {
        let event = MeetingEvent(
            id: "cz-exchange",
            title: "Синк",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work",
            notes: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169",
            url: URL(string: "https://chatzone.o3t.ru/meet/town-square")
        )
        let url = detector.detect(in: event)
        XCTAssertEqual(url?.path, "/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")
    }

    func testIgnoresWeakChatZoneSlugInURLFieldWhenNoNotes() {
        let event = MeetingEvent(
            id: "cz-weak",
            title: "Синк",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            calendarId: "c",
            calendarTitle: "Work",
            url: URL(string: "https://chatzone.o3t.ru/meet/town-square")
        )
        XCTAssertNil(detector.detect(in: event))
    }

    func testChatZoneLaunchURLOpensInAppDeepLink() {
        let https = URL(string: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")!
        let launch = detector.launchURL(for: https)
        XCTAssertEqual(launch.scheme, "mattermost")
        XCTAssertEqual(launch.host, "chatzone.o3t.ru")
        XCTAssertEqual(launch.path, "/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")
        XCTAssertTrue(launch.query?.contains("showMeetInApp=true") == true)
    }

    func testChatZoneChannelLinkRewritesToMattermost() {
        let https = URL(string: "https://chatzone.o3t.ru/chatzone/channels/town-square")!
        let launch = detector.launchURL(for: https)
        XCTAssertEqual(launch.scheme, "mattermost")
        XCTAssertEqual(launch.host, "chatzone.o3t.ru")
        XCTAssertEqual(launch.path, "/chatzone/channels/town-square")
        XCTAssertNil(launch.query)
    }

    func testHttpsURLFromMattermostDeepLink() {
        let deep = URL(string: "mattermost://chatzone.o3t.ru/meet/abc?showMeetInApp=true")!
        let https = detector.httpsURL(from: deep)
        XCTAssertEqual(https.scheme, "https")
        XCTAssertEqual(https.host, "chatzone.o3t.ru")
        XCTAssertEqual(https.path, "/meet/abc")
    }

    func testLaunchURLFromMattermostIsStable() {
        let deep = URL(string: "mattermost://chatzone.o3t.ru/meet/abc?showMeetInApp=true")!
        let launch = detector.launchURL(for: deep)
        XCTAssertEqual(launch.scheme, "mattermost")
        XCTAssertEqual(launch.path, "/meet/abc")
        XCTAssertTrue(launch.query?.contains("showMeetInApp=true") == true)
    }
}
