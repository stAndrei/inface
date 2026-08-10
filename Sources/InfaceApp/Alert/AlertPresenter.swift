import AppKit
import InfaceCore
import SwiftUI

@MainActor
final class AlertPresenter: ObservableObject {
    private let model: AppModel
    private var controllers: [AlertWindowController] = []
    private var observation: NSKeyValueObservation?

    init(model: AppModel) {
        self.model = model
        // Poll published changes via timer-friendly sink using Notification workaround:
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sync()
            }
        }
    }

    private func sync() {
        if let event = model.activeAlert {
            if controllers.isEmpty {
                show(event)
            }
        } else if !controllers.isEmpty {
            hide()
        }
    }

    private func show(_ event: MeetingEvent) {
        hide()
        for screen in NSScreen.screens {
            let controller = AlertWindowController(
                event: event,
                meetingURL: model.linkDetector.detect(in: event),
                onJoin: { [weak self] in
                    _ = self?.model.joinMeeting(for: event)
                    self?.model.dismissAlert()
                },
                onDismiss: { [weak self] in
                    self?.model.dismissAlert()
                },
                onSnooze: { [weak self] minutes in
                    self?.model.snoozeAlert(minutes: minutes)
                }
            )
            controller.show(on: screen)
            controllers.append(controller)
        }
    }

    private func hide() {
        controllers.forEach { $0.close() }
        controllers.removeAll()
    }
}
