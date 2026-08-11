import InfaceCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var appeared = false
    @State private var selectedEvent: MeetingEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

            if selectedEvent == nil {
                daySwitcher
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }

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
                        },
                        onOpenLink: { url in
                            _ = model.openLink(url)
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
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
        }
        .frame(width: 520, height: 740)
        .background(InfaceTheme.background)
        .opacity(appeared ? 1 : 0)
        .background(
            PopoverShownObserver {
                model.presentPopover()
                selectedEvent = nil
            }
        )
        .onAppear {
            model.start()
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
        .onChange(of: model.selectedDay) { _, _ in
            selectedEvent = nil
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Inface")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(InfaceTheme.textPrimary)
            Spacer()
            if model.settings.alertsPaused {
                Text("Пауза")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(InfaceTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(InfaceTheme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
            Button {
                openAppSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(InfaceTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(InfaceTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Настройки")
        }
    }

    private func openAppSettings() {
        openSettings()
        model.openSettings()
    }

    private var daySwitcher: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    model.shiftDay(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(InfaceTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(InfaceTheme.textPrimary)
            .help("Предыдущий день")

            VStack(spacing: 4) {
                Text(dayTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(InfaceTheme.textPrimary)
                Text(daySubtitle)
                    .font(.callout)
                    .foregroundStyle(InfaceTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    model.shiftDay(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(InfaceTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(InfaceTheme.textPrimary)
            .help("Следующий день")
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        if model.isSelectedDayToday {
            formatter.dateFormat = "EEEE, d MMMM"
            return "Сегодня · \(formatter.string(from: model.selectedDay).capitalized)"
        }
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: model.selectedDay).capitalized
    }

    private var daySubtitle: String {
        let count = model.selectedDayEvents.count
        if count == 0 { return "нет встреч" }
        return "\(count) \(meetingsWord(count))"
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
            if model.usesExchange {
                emptyState(
                    title: "Exchange ещё не подключён",
                    button: "Открыть настройки"
                ) {
                    model.openSettings()
                }
                .padding(.horizontal, 18)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    emptyState(
                        title: "Календари ещё не подключены",
                        button: "Запросить доступ к Календарю"
                    ) {
                        Task { await model.requestAccess() }
                    }
                    Button("Подключить Exchange…") {
                        model.openExchangeSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(InfaceTheme.accent)
                    .controlSize(.large)
                    Text("Exchange: логин @ozon.ru и пароль код:пароль из @mail-bot в Chatzone — в настройках.")
                        .font(.callout)
                        .foregroundStyle(InfaceTheme.textSecondary)
                }
                .padding(.horizontal, 18)
            }
        case .denied, .restricted:
            if model.usesExchange {
                emptyState(
                    title: "Не удалось войти в Exchange",
                    button: "Открыть настройки"
                ) {
                    model.openSettings()
                }
                .padding(.horizontal, 18)
            } else {
                emptyState(
                    title: "Нет доступа к Календарю",
                    button: "Открыть настройки"
                ) {
                    model.openSystemCalendarPrivacy()
                }
                .padding(.horizontal, 18)
            }
        case .authorized:
            DayTimelineView(
                timeline: DayTimelineBuilder.build(
                    events: model.selectedDayEvents,
                    day: model.selectedDay
                ),
                now: Date(),
                onSelect: { event in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedEvent = event
                    }
                }
            )
            .padding(.top, 2)
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button(model.settings.alertsPaused ? "Возобновить" : "Пауза") {
                model.togglePause()
            }
            .buttonStyle(.plain)
            .font(.body.weight(.semibold))
            .foregroundStyle(InfaceTheme.accent)

            if !model.isSelectedDayToday {
                Button("Сегодня") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        model.goToToday()
                    }
                }
                .buttonStyle(.plain)
                .font(.body.weight(.semibold))
                .foregroundStyle(InfaceTheme.textPrimary)
            }

            Spacer()

            Button("Настройки") {
                openAppSettings()
            }
            .buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(InfaceTheme.textSecondary)

            Button("Обновить") {
                model.reloadEvents()
            }
            .buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(InfaceTheme.textSecondary)
        }
    }

    private func emptyState(title: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3)
                .foregroundStyle(InfaceTheme.textSecondary)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .tint(InfaceTheme.accent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EventDetailView: View {
    let event: MeetingEvent
    let onBack: () -> Void
    let onJoin: () -> Void
    let onOpenLink: (URL) -> Void
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("К списку")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(InfaceTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(event.title)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(InfaceTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    detailBlock(title: "Время", value: timeRange)
                    if !event.calendarTitle.isEmpty {
                        detailBlock(title: "Календарь", value: event.calendarTitle)
                    }
                    if let location = event.location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        linkAwareBlock(title: "Место", text: location)
                    }
                    if let url = detector.detect(in: event) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ссылка")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(InfaceTheme.textSecondary)
                            Button(url.absoluteString) {
                                onOpenLink(url)
                            }
                            .buttonStyle(.plain)
                            .font(.title3)
                            .foregroundStyle(InfaceTheme.accent)
                            .underline()
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                        }
                        Button(action: onJoin) {
                            Text("Подключиться")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(InfaceTheme.accent)
                                .foregroundStyle(Color.black.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    if let notes = event.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Заметки")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(InfaceTheme.textSecondary)
                            Text(Linkifier.attributedString(from: notes))
                            .font(.title3)
                            .textSelection(.enabled)
                            .environment(\.openURL, OpenURLAction { url in
                                onOpenLink(url)
                                return .handled
                            })
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(InfaceTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func detailBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(InfaceTheme.textSecondary)
            Text(value)
                .font(.title3)
                .foregroundStyle(InfaceTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func linkAwareBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(InfaceTheme.textSecondary)
            Text(Linkifier.attributedString(from: text))
            .font(.title3)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                onOpenLink(url)
                return .handled
            })
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
