import AppKit
import Foundation

public struct WorkspaceLinkOpener: LinkOpening {
    public init() {}
    public func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
