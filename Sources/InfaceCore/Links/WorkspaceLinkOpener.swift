import AppKit
import Foundation

public struct WorkspaceLinkOpener: LinkOpening {
    public static let chatzoneBundleIDs = [
        "Chatzone.Desktop",
        "chatzone.desktop"
    ]

    public init() {}

    public func open(_ url: URL) -> Bool {
        let detector = MeetingLinkDetector.shared

        guard detector.isChatZoneRelated(url) else {
            return NSWorkspace.shared.open(url)
        }

        // Always derive from https so deep-link rewrite is deterministic.
        let httpsURL = detector.httpsURL(from: url)
        let deepLink = detector.launchURL(for: httpsURL)

        if let appURL = Self.findChatZoneApp() {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            // Open deep link *with* ChatZone — never via default handler (browsers mangle mattermost://).
            NSWorkspace.shared.open(
                [deepLink],
                withApplicationAt: appURL,
                configuration: configuration
            ) { _, error in
                guard error != nil else { return }
                // Fallback: hand https meet link to ChatZone (still not the browser).
                NSWorkspace.shared.open(
                    [httpsURL],
                    withApplicationAt: appURL,
                    configuration: configuration,
                    completionHandler: nil
                )
            }
            return true
        }

        // ChatZone not installed: open correct https (not mattermost:// — browsers show a broken URL).
        return NSWorkspace.shared.open(httpsURL)
    }

    public static func findChatZoneApp() -> URL? {
        for id in chatzoneBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return url
            }
        }

        let candidates = [
            "/Applications/Chatzone.app",
            "/Applications/ChatZone.app",
            NSHomeDirectory() + "/Applications/Chatzone.app",
            NSHomeDirectory() + "/Applications/ChatZone.app"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
