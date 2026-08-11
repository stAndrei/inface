import AppKit
import SwiftUI

/// Fires when the menu bar popover window is shown again.
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

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillShow),
                name: NSWindow.willOrderFrontNotification,
                object: window
            )
        }

        @objc private func windowWillShow() {
            onShown?()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
