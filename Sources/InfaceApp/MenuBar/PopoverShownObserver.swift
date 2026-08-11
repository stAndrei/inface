import AppKit
import SwiftUI

/// Fires when the menu bar popover window becomes key again after being dismissed.
struct PopoverShownObserver: NSViewRepresentable {
    let onShown: () -> Void

    func makeNSView(context: Context) -> ObservingView {
        let view = ObservingView()
        view.onShown = onShown
        return view
    }

    func updateNSView(_ nsView: ObservingView, context: Context) {
        nsView.onShown = onShown
    }

    final class ObservingView: NSView {
        var onShown: (() -> Void)?
        private var isPopoverKey = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }

        @objc private func windowDidBecomeKey() {
            guard !isPopoverKey else { return }
            isPopoverKey = true
            onShown?()
        }

        @objc private func windowDidResignKey() {
            isPopoverKey = false
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
