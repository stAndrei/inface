import AppKit
import Foundation

public struct WorkspaceLinkOpener: LinkOpening {
    public static let chatzoneBundleID = "Chatzone.Desktop"

    public init() {}

    public func open(_ url: URL) -> Bool {
        let detector = MeetingLinkDetector.shared
        let launchURL = detector.launchURL(for: url)

        if NSWorkspace.shared.open(launchURL) {
            return true
        }

        // Fallback: ask ChatZone.app to open the original/https URL.
        if detector.isChatZoneMeetURL(url) || detector.isChatZoneHost(url.host?.lowercased() ?? ""),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.chatzoneBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration, completionHandler: nil)
            return true
        }

        // Last resort: try chatzone:// scheme variant
        if detector.isChatZoneMeetURL(url),
           var components = URLComponents(url: launchURL, resolvingAgainstBaseURL: false) {
            components.scheme = "chatzone"
            if let alt = components.url, NSWorkspace.shared.open(alt) {
                return true
            }
        }

        return NSWorkspace.shared.open(url)
    }
}
