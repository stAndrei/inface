import AppKit
import Foundation

public struct WorkspaceLinkOpener: LinkOpening {
    public static let chatzoneBundleID = "Chatzone.Desktop"

    public init() {}

    public func open(_ url: URL) -> Bool {
        let detector = MeetingLinkDetector.shared
        let launchURL = detector.launchURL(for: url)

        // Prefer ChatZone.app explicitly — https://chatzone… defaults to the browser.
        if detector.isChatZoneRelated(url) || detector.isChatZoneRelated(launchURL),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.chatzoneBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([launchURL], withApplicationAt: appURL, configuration: configuration, completionHandler: nil)
            return true
        }

        if NSWorkspace.shared.open(launchURL) {
            return true
        }

        // Last resort: try chatzone:// scheme variant for meet links.
        if detector.isChatZoneMeetURL(url) || detector.isChatZoneMeetURL(launchURL),
           var components = URLComponents(url: launchURL, resolvingAgainstBaseURL: false) {
            components.scheme = "chatzone"
            if let alt = components.url, NSWorkspace.shared.open(alt) {
                return true
            }
        }

        return NSWorkspace.shared.open(url)
    }
}
