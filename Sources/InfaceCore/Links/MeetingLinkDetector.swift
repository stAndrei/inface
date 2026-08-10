import Foundation

public struct MeetingLinkDetector: Sendable {
    public static let shared = MeetingLinkDetector()

    private let hostMarkers: [String] = [
        "zoom.us", "zoom.com", "zoomgov.com",
        "meet.google.com",
        "teams.microsoft.com", "teams.live.com",
        "webex.com",
        "gotomeeting.com", "gotowebinar.com",
        "whereby.com",
        "around.co",
        "facetime.apple.com",
        "skype.com", "join.skype.com",
        "bluejeans.com",
        "meet.jit.si",
        "discord.gg", "discord.com",
        "meetings.ringcentral.com", "v.ringcentral.com",
        "chime.aws",
        "workplace.com",
        "larksuite.com",
        "feishu.cn",
        "meetup.com",
        "gather.town",
        "miro.com",
        "chatzone.o3t.ru",
        "chatzone.o3.ru"
    ]

    private let urlRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"https?://[^\s<>\"']+"#,
            options: .caseInsensitive
        )
    }()

    public init() {}

    public func detect(in event: MeetingEvent) -> URL? {
        if let url = event.url, isConferenceURL(url) {
            return url
        }
        if let notes = event.notes, let url = firstConferenceURL(in: notes) {
            return url
        }
        if let location = event.location, let url = firstConferenceURL(in: location) {
            return url
        }
        return nil
    }

    public func firstConferenceURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = urlRegex.matches(in: text, options: [], range: range)
        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            var raw = String(text[swiftRange])
            while let last = raw.last, ".,);]".contains(last) {
                raw.removeLast()
            }
            if let url = URL(string: raw), isConferenceURL(url) {
                return url
            }
        }
        return nil
    }

    public func isConferenceURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if isChatZoneHost(host) {
            return true
        }
        let path = url.path.lowercased()
        if (host == "msg.o3.ru" || host == "msg-beta.o3.ru"), path.hasPrefix("/meet") {
            return true
        }
        return hostMarkers.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    /// ChatZone desktop opens Meetzone for `mattermost://host/meet/id?showMeetInApp=true`.
    public func launchURL(for url: URL) -> URL {
        guard isChatZoneMeetURL(url) || isChatZoneHost(url.host?.lowercased() ?? "") else {
            return url
        }
        // Only rewrite meet paths into in-app deep links.
        guard isChatZoneMeetURL(url) else { return url }

        var components = URLComponents()
        components.scheme = "mattermost"
        components.host = url.host
        components.path = url.path.isEmpty ? "/" : url.path

        var items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        items.removeAll { $0.name == "showMeetInApp" || $0.name == "openMeetInApp" }
        items.append(URLQueryItem(name: "showMeetInApp", value: "true"))
        components.queryItems = items

        return components.url ?? url
    }

    public func isChatZoneMeetURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased()
        let isMeetPath = path.hasPrefix("/meet/") || path == "/meet"
        guard isMeetPath else { return false }
        return isChatZoneHost(host)
            || host == "msg.o3.ru"
            || host == "msg-beta.o3.ru"
    }

    public func isChatZoneHost(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "chatzone.o3t.ru" || host.hasSuffix(".chatzone.o3t.ru") { return true }
        if host == "chatzone.o3.ru" || host.hasSuffix(".chatzone.o3.ru") { return true }
        return host.contains("chatzone") && (host.hasSuffix(".o3t.ru") || host.hasSuffix(".o3.ru"))
    }
}

public protocol LinkOpening: Sendable {
    func open(_ url: URL) -> Bool
}

public final class MockLinkOpener: LinkOpening, @unchecked Sendable {
    public private(set) var opened: [URL] = []
    public init() {}
    public func open(_ url: URL) -> Bool {
        opened.append(url)
        return true
    }
}
