import AppKit
import Foundation

enum MenuBarPopoverDismisser {
    /// Closes the MenuBarExtra window-style popover after an action (e.g. Join).
    @MainActor
    static func dismiss() {
        let windows = NSApp.windows.filter(\.isVisible)

        for window in windows {
            let typeName = String(describing: type(of: window))
            let looksLikeMenuExtra =
                typeName.contains("MenuBarExtra")
                || typeName.contains("StatusItem")
                || window.level == .floating
                || window.level == .popUpMenu
                || (window.styleMask.contains(.nonactivatingPanel) && window.isKeyWindow)

            if looksLikeMenuExtra || window.isKeyWindow {
                window.orderOut(nil)
                window.close()
            }
        }

        // Let ChatZone become active after opening the meet link.
        NSApp.deactivate()
    }
}
