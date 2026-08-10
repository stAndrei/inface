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

    func testChatZoneLaunchURLOpensInAppDeepLink() {
        let https = URL(string: "https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")!
        let launch = detector.launchURL(for: https)
        XCTAssertEqual(launch.scheme, "mattermost")
        XCTAssertEqual(launch.host, "chatzone.o3t.ru")
        XCTAssertEqual(launch.path, "/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169")
        XCTAssertTrue(launch.query?.contains("showMeetInApp=true") == true)
    }
}
