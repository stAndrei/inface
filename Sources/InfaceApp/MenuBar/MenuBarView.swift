import InfaceCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            footer
        }
        .padding(16)
        .frame(width: 340)
        .background(InfaceTheme.background)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            model.start()
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    private var header: some View {
        HStack {
            Text("Inface")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(InfaceTheme.textPrimary)
            Spacer()
            if model.settings.alertsPaused {
                Text("Пауза")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InfaceTheme.accent)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.authStatus {
        case .notDetermined:
            emptyState(
                title: "Календари ещё не подключены",
                button: "Запросить доступ к Календарю"
            ) {
                Task { await model.requestAccess() }
            }
        case .denied, .restricted:
            emptyState(
                title: "Нет доступа к Календарю",
                button: "Открыть настройки"
            ) {
                model.openSystemCalendarPrivacy()
            }
        case .authorized:
            if model.events.isEmpty {
                Text("Нет ближайших событий")
                    .foregroundStyle(InfaceTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                eventList
            }
        }
    }

    private var eventList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.events.prefix(12)) { event in
                    EventRow(event: event) {
                        _ = model.joinMeeting(for: event)
                    }
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private var footer: some View {
        HStack {
            Button(model.settings.alertsPaused ? "Возобновить" : "Пауза") {
                model.togglePause()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(InfaceTheme.accent)
            Spacer()
            Button("Обновить") { model.reloadEvents() }
                .buttonStyle(.borderless)
                .foregroundStyle(InfaceTheme.textSecondary)
        }
        .font(.caption)
    }

    private func emptyState(title: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .foregroundStyle(InfaceTheme.textSecondary)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .tint(InfaceTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EventRow: View {
    let event: MeetingEvent
    let onJoin: () -> Void
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(InfaceTheme.textPrimary)
                    .lineLimit(2)
                Spacer()
                if event.isOngoing {
                    Text("сейчас")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(InfaceTheme.accent)
                }
            }
            Text(timeLabel)
                .font(.caption)
                .foregroundStyle(InfaceTheme.textSecondary)
            if detector.detect(in: event) != nil {
                Button("Подключиться", action: onJoin)
                    .buttonStyle(.borderless)
                    .foregroundStyle(InfaceTheme.accent)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(10)
        .background(InfaceTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: event.startDate)
    }
}
