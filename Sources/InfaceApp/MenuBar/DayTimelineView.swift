import InfaceCore
import SwiftUI

struct DayTimelineView: View {
    let timeline: DayTimelineModel
    let now: Date
    let onSelect: (MeetingEvent) -> Void

    private let hourHeight: CGFloat = 96
    private let gutterWidth: CGFloat = 64
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    hourGrid
                    contentColumn
                    if timeline.isToday {
                        nowLine
                            .id("now-line")
                    }
                }
                .frame(height: totalHeight + 16)
                .padding(.trailing, 12)
                .padding(.leading, 8)
                .padding(.bottom, 12)
                .id(timeline.dayStart.timeIntervalSince1970)
            }
            .onAppear { scrollToRelevant(proxy) }
            .onChange(of: timeline.dayStart) { _, _ in
                scrollToRelevant(proxy)
            }
        }
    }

    private func scrollToRelevant(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.25)) {
                if timeline.isToday {
                    proxy.scrollTo("now-line", anchor: .center)
                } else if let first = timeline.meetings.first {
                    proxy.scrollTo("meeting-\(first.id)", anchor: .top)
                }
            }
        }
    }

    private var totalHeight: CGFloat {
        CGFloat(timeline.visibleDuration / 60.0) * (hourHeight / 60.0)
    }

    private var hourGrid: some View {
        let hours = DayTimelineBuilder.hours(from: timeline.visibleStart, to: timeline.dayEnd)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
                let y = yOffset(for: hour)
                HStack(alignment: .center, spacing: 10) {
                    Text(hourLabel(hour))
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(InfaceTheme.textSecondary)
                        .frame(width: gutterWidth - 8, alignment: .trailing)
                    Rectangle()
                        .fill(InfaceTheme.textSecondary.opacity(0.2))
                        .frame(height: 1)
                }
                .offset(y: y)
            }
        }
    }

    private var contentColumn: some View {
        ZStack(alignment: .topLeading) {
            ForEach(timeline.intervals) { interval in
                switch interval.kind {
                case .free:
                    freeGap(interval)
                case .meeting(let event):
                    meetingBlock(event, start: interval.start, end: interval.end)
                        .id("meeting-\(event.id)")
                }
            }
        }
        .padding(.leading, gutterWidth)
    }

    @ViewBuilder
    private func freeGap(_ gap: DayTimelineInterval) -> some View {
        let y = yOffset(for: gap.start)
        let h = max(height(for: gap.duration), 1)
        Group {
            if gap.duration >= 12 * 60 {
                Text(freeLabel(for: gap))
                    .font(.callout)
                    .foregroundStyle(InfaceTheme.textSecondary.opacity(0.75))
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, minHeight: h, maxHeight: h, alignment: .leading)
            } else {
                Color.clear.frame(height: h)
            }
        }
        .offset(y: y)
    }

    private func meetingBlock(_ event: MeetingEvent, start: Date, end: Date) -> some View {
        let y = yOffset(for: start)
        let h = max(height(for: end.timeIntervalSince(start)), 36)
        let isPast = timeline.isToday && event.endDate <= now

        return Button {
            onSelect(event)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(InfaceTheme.accent.opacity(isPast ? 0.45 : 1))
                    .frame(width: 5)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(event.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(InfaceTheme.textPrimary.opacity(isPast ? 0.65 : 1))
                            .lineLimit(h < 56 ? 1 : 2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 6)
                        if event.isOngoing {
                            Text("сейчас")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(InfaceTheme.accent)
                        }
                    }
                    Text(timeRange(event))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(InfaceTheme.textSecondary)
                    if h >= 64 {
                        HStack(spacing: 8) {
                            if !event.calendarTitle.isEmpty {
                                Text(event.calendarTitle)
                                    .lineLimit(1)
                            }
                            if detector.detect(in: event) != nil {
                                Text("ссылка")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(InfaceTheme.accent)
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(InfaceTheme.textSecondary.opacity(0.95))
                    }
                }
                .padding(.vertical, 8)
                .padding(.trailing, 10)
            }
            .frame(maxWidth: .infinity, minHeight: h, maxHeight: h, alignment: .topLeading)
            .background(InfaceTheme.accent.opacity(event.isOngoing ? 0.24 : (isPast ? 0.08 : 0.16)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(InfaceTheme.accent.opacity(isPast ? 0.2 : 0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .offset(y: y)
        .accessibilityHint("Показать подробности")
    }

    @ViewBuilder
    private var nowLine: some View {
        if now >= timeline.visibleStart && now <= timeline.dayEnd {
            let y = yOffset(for: now)
            HStack(spacing: 0) {
                Circle()
                    .fill(InfaceTheme.danger)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(InfaceTheme.danger)
                    .frame(height: 2)
            }
            .padding(.leading, gutterWidth - 5)
            .offset(y: y - 4)
            .accessibilityLabel("Сейчас")
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let minutes = date.timeIntervalSince(timeline.visibleStart) / 60.0
        return CGFloat(max(minutes, 0)) * (hourHeight / 60.0)
    }

    private func height(for duration: TimeInterval) -> CGFloat {
        CGFloat(max(duration, 60) / 60.0) * (hourHeight / 60.0)
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func timeRange(_ event: MeetingEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate))–\(formatter.string(from: event.endDate))"
    }

    private func freeLabel(for gap: DayTimelineInterval) -> String {
        let minutes = Int(gap.duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let rem = minutes % 60
            if rem == 0 { return "Свободно · \(hours) ч" }
            return "Свободно · \(hours) ч \(rem) мин"
        }
        return "Свободно · \(minutes) мин"
    }
}
