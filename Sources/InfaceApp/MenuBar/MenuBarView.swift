import InfaceCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var appeared = false
    @State private var selectedEvent: MeetingEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Group {
                if let selectedEvent {
                    EventDetailView(
                        event: selectedEvent,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                self.selectedEvent = nil
                            }
                        },
                        onJoin: {
                            _ = model.joinMeeting(for: selectedEvent)
                            MenuBarPopoverDismisser.dismiss()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    content
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if selectedEvent == nil {
                footer
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .frame(width: 440, height: 620)
        .background(InfaceTheme.background)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            model.start()
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inface")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(InfaceTheme.textPrimary)
                Text(daySubtitle)
                    .font(.caption)
                    .foregroundStyle(InfaceTheme.textSecondary)
            }
            Spacer()
            if model.settings.alertsPaused {
                Text("Пауза")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InfaceTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(InfaceTheme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var daySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let count = model.todaysRemainingEvents.count
        let meetings = count == 0 ? "нет встреч" : "\(count) \(meetingsWord(count))"
        return "\(formatter.string(from: Date()).capitalized) · \(meetings) до конца дня"
    }

    private func meetingsWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "встреча" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "встречи" }
        return "встреч"
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
            .padding(.horizontal, 16)
        case .denied, .restricted:
            emptyState(
                title: "Нет доступа к Календарю",
                button: "Открыть настройки"
            ) {
                model.openSystemCalendarPrivacy()
            }
            .padding(.horizontal, 16)
        case .authorized:
            if model.todaysRemainingEvents.isEmpty {
                Text("На сегодня больше нет встреч")
                    .foregroundStyle(InfaceTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
            } else {
                eventList
            }
        }
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(model.todaysRemainingEvents) { event in
                    EventRow(event: event) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedEvent = event
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var footer: some View {
        HStack {
            Button(model.settings.alertsPaused ? "Возобновить" : "Пауза") {
                model.togglePause()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(InfaceTheme.accent)
            Spacer()
            Button("Обновить") {
                model.reloadEvents()
            }
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
    let onSelect: () -> Void
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(event.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(InfaceTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if event.isOngoing {
                        Text("сейчас")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(InfaceTheme.accent)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(InfaceTheme.textSecondary.opacity(0.7))
                }
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(InfaceTheme.textSecondary)
                HStack(spacing: 8) {
                    if !event.calendarTitle.isEmpty {
                        Text(event.calendarTitle)
                            .font(.caption2)
                            .foregroundStyle(InfaceTheme.textSecondary.opacity(0.85))
                            .lineLimit(1)
                    }
                    if detector.detect(in: event) != nil {
                        Text("есть ссылка")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(InfaceTheme.accent)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InfaceTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Показать подробности")
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start)–\(end)"
    }
}

struct EventDetailView: View {
    let event: MeetingEvent
    let onBack: () -> Void
    let onJoin: () -> Void
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("К списку")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(InfaceTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(event.title)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(InfaceTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    detailBlock(title: "Время", value: timeRange)
                    if !event.calendarTitle.isEmpty {
                        detailBlock(title: "Календарь", value: event.calendarTitle)
                    }
                    if let location = event.location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailBlock(title: "Место", value: location)
                    }
                    if let url = detector.detect(in: event) {
                        detailBlock(title: "Ссылка", value: url.absoluteString)
                        Button(action: onJoin) {
                            Text("Подключиться")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(InfaceTheme.accent)
                                .foregroundStyle(Color.black.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    if let notes = event.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Заметки")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(InfaceTheme.textSecondary)
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(InfaceTheme.textPrimary)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(InfaceTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func detailBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(InfaceTheme.textSecondary)
            Text(value)
                .font(.body)
                .foregroundStyle(InfaceTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var timeRange: String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "ru_RU")
        day.dateFormat = "EEEE, d MMMM"
        let time = DateFormatter()
        time.locale = Locale(identifier: "ru_RU")
        time.dateFormat = "HH:mm"
        return "\(day.string(from: event.startDate).capitalized)\n\(time.string(from: event.startDate)) – \(time.string(from: event.endDate))"
    }
}
