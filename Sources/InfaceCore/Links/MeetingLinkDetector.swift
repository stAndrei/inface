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

    private let meetUUIDRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#,
            options: []
        )
    }()

    public init() {}

    public func detect(in event: MeetingEvent) -> URL? {
        selectBestConferenceURL(from: conferenceURLCandidates(in: event))
    }

    private func conferenceURLCandidates(in event: MeetingEvent) -> [URL] {
        var candidates: [URL] = []
        if let notes = event.notes {
            candidates.append(contentsOf: allConferenceURLs(in: notes))
        }
        if let location = event.location {
            candidates.append(contentsOf: allConferenceURLs(in: location))
        }
        if let url = event.url, isConferenceURL(url) {
            candidates.append(url)
        }
        return candidates
    }

    private func selectBestConferenceURL(from candidates: [URL]) -> URL? {
        guard !candidates.isEmpty else { return nil }

        if let uuidMeet = candidates.first(where: isChatZoneMeetUUID) {
            return httpsURL(from: uuidMeet)
        }

        if let strong = candidates.first(where: { !isWeakChatZoneURL($0) }) {
            return strong
        }

        return candidates.first
    }

    public func allConferenceURLs(in text: String) -> [URL] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = urlRegex.matches(in: text, options: [], range: range)
        var urls: [URL] = []

        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            var raw = String(text[swiftRange])
            while let last = raw.last, ".,);]".contains(last) {
                raw.removeLast()
            }
            guard let url = URL(string: raw), isConferenceURL(url) else { continue }
            if !urls.contains(url) {
                urls.append(url)
            }
        }

        return urls
    }

    public func firstConferenceURL(in text: String) -> URL? {
        allConferenceURLs(in: text).first
    }

    public func isConferenceURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        // ChatZone / msg: only real Meetzone UUID links — not channels or /meet/town-square.
        if isChatZoneHost(host) || host == "msg.o3.ru" || host == "msg-beta.o3.ru" {
            return isChatZoneMeetUUID(url)
        }
        return hostMarkers.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    /// ChatZone desktop handles `mattermost://` / `chatzone://`. HTTPS always opens in the browser
    /// unless opened explicitly with ChatZone.app.
    public func launchURL(for url: URL) -> URL {
        let source = httpsURL(from: url)
        guard isChatZoneRelated(source) else { return url }

        var components = URLComponents()
        components.scheme = "mattermost"
        // Desktop Meetzone expects chatzone.o3t.ru, not msg.o3.ru aliases.
        components.host = canonicalChatZoneHost(source.host)
        components.path = source.path.isEmpty ? "/" : source.path
        components.fragment = source.fragment

        var items = URLComponents(url: source, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if isChatZoneMeetUUID(source) {
            items.removeAll { $0.name == "showMeetInApp" || $0.name == "openMeetInApp" }
            items.append(URLQueryItem(name: "showMeetInApp", value: "true"))
        }
        components.queryItems = items.isEmpty ? nil : items

        return components.url ?? url
    }

    /// Normalize mattermost/chatzone deep links back to https for safe browser fallback.
    /// Calendar often stores `/meetzone/{uuid}`; ChatZone only resolves `/meet/{uuid}`
    /// (unknown paths fall back to `/meet/town-square`).
    public func httpsURL(from url: URL) -> URL {
        let working = urlWithHTTPSScheme(url)
        guard isChatZoneMeetUUID(working) else { return working }

        var components = URLComponents(url: working, resolvingAgainstBaseURL: false) ?? URLComponents()
        let slug = chatZoneMeetSlug(from: working)
        guard !slug.isEmpty else { return working }
        components.path = "/meet/\(slug)"
        return components.url ?? working
    }

    public func isChatZoneRelated(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        if scheme == "chatzone" || scheme == "mattermost" {
            guard let host = url.host?.lowercased() else { return true }
            return isChatZoneHost(host) || host == "msg.o3.ru" || host == "msg-beta.o3.ru"
        }
        guard let host = url.host?.lowercased() else { return false }
        return isChatZoneHost(host) || host == "msg.o3.ru" || host == "msg-beta.o3.ru"
    }

    public func isChatZoneMeetURL(_ url: URL) -> Bool {
        isChatZoneMeetUUID(url)
    }

    public func isChatZoneMeetUUID(_ url: URL) -> Bool {
        let url = urlWithHTTPSScheme(url)
        guard let host = url.host?.lowercased() else { return false }
        guard isChatZoneHost(host) || host == "msg.o3.ru" || host == "msg-beta.o3.ru" else { return false }

        let slug = chatZoneMeetSlug(from: url)
        guard !slug.isEmpty else { return false }

        let range = NSRange(slug.startIndex..<slug.endIndex, in: slug)
        return meetUUIDRegex.firstMatch(in: slug, options: [], range: range) != nil
    }

    /// Exchange often puts `/meet/town-square` in the URL field — not a real meet link.
    public func isWeakChatZoneURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        guard isChatZoneHost(host) || host == "msg.o3.ru" || host == "msg-beta.o3.ru" else {
            return false
        }
        if isChatZoneMeetUUID(url) { return false }
        let path = url.path.lowercased()
        if path.hasPrefix("/meet/") { return true }
        if path.contains("/channels/") || path.contains("/messages/") || path.contains("/pl/") {
            return true
        }
        return true
    }

    private func urlWithHTTPSScheme(_ url: URL) -> URL {
        let scheme = url.scheme?.lowercased()
        guard scheme == "mattermost" || scheme == "chatzone" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.scheme = "https"
        return components.url ?? url
    }

    private func chatZoneMeetSlug(from url: URL) -> String {
        let path = url.path
        let lower = path.lowercased()
        for prefix in ["/meetzone/", "/meet/"] {
            guard lower.hasPrefix(prefix) else { continue }
            let remainder = String(path.dropFirst(prefix.count))
            return remainder.split(separator: "/").first.map(String.init) ?? ""
        }
        return ""
    }

    public func isChatZoneHost(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "chatzone.o3t.ru" || host.hasSuffix(".chatzone.o3t.ru") { return true }
        if host == "chatzone.o3.ru" || host.hasSuffix(".chatzone.o3.ru") { return true }
        return host.contains("chatzone") && (host.hasSuffix(".o3t.ru") || host.hasSuffix(".o3.ru"))
    }

    public func canonicalChatZoneHost(_ host: String?) -> String {
        let host = (host ?? "").lowercased()
        if host == "msg.o3.ru" || host == "msg-beta.o3.ru" {
            return "chatzone.o3t.ru"
        }
        if host.isEmpty { return "chatzone.o3t.ru" }
        return host
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
