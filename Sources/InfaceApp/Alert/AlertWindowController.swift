import AppKit
import InfaceCore
import SwiftUI

final class AlertWindowController {
    private var window: NSWindow?
    private let rootView: AlertContentView

    init(
        event: MeetingEvent,
        onJoin: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onSnooze: @escaping (Int) -> Void
    ) {
        rootView = AlertContentView(
            event: event,
            onJoin: onJoin,
            onDismiss: onDismiss,
            onSnooze: onSnooze
        )
    }

    func show(on screen: NSScreen) {
        let hosting = NSHostingView(rootView: rootView)
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        window = panel
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}

struct AlertContentView: View {
    let event: MeetingEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            InfaceTheme.alertGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Скоро встреча")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(InfaceTheme.accent)
                Text(event.title)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(InfaceTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(timeText)
                    .font(.title3)
                    .foregroundStyle(InfaceTheme.textSecondary)
                HStack(spacing: 12) {
                    Button("Подключиться", action: onJoin)
                        .buttonStyle(AlertPrimaryButtonStyle())
                    Button("Закрыть", action: onDismiss)
                        .buttonStyle(AlertSecondaryButtonStyle())
                    Button("Отложить 5 мин") { onSnooze(5) }
                        .buttonStyle(AlertSecondaryButtonStyle())
                    Button("Отложить 10 мин") { onSnooze(10) }
                        .buttonStyle(AlertSecondaryButtonStyle())
                }
            }
            .padding(48)
            .scaleEffect(appeared ? 1 : 0.98)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return "Начало в \(formatter.string(from: event.startDate))"
    }
}

private struct AlertPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(InfaceTheme.accent.opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundStyle(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AlertSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(InfaceTheme.backgroundSecondary.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundStyle(InfaceTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
