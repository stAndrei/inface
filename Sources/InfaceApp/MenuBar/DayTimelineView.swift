import InfaceCore
import SwiftUI

struct DayTimelineView: View {
    let timeline: DayTimelineModel
    let now: Date
    let onSelect: (MeetingEvent) -> Void

    private let hourHeight: CGFloat = 72
    private let gutterWidth: CGFloat = 52
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    hourGrid
                    contentColumn
                    nowLine
                        .id("now-line")
                }
                .frame(height: totalHeight + 12)
                .padding(.trailing, 10)
                .padding(.leading, 6)
                .padding(.bottom, 8)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("now-line", anchor: .center)
                    }
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
                HStack(alignment: .center, spacing: 8) {
                    Text(hourLabel(hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(InfaceTheme.textSecondary)
                        .frame(width: gutterWidth - 6, alignment: .trailing)
                    Rectangle()
                        .fill(InfaceTheme.textSecondary.opacity(0.18))
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
                    .font(.caption2)
                    .foregroundStyle(InfaceTheme.textSecondary.opacity(0.7))
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, minHeight: h, maxHeight: h, alignment: .leading)
            } else {
                Color.clear.frame(height: h)
            }
        }
        .offset(y: y)
    }

    private func meetingBlock(_ event: MeetingEvent, start: Date, end: Date) -> some View {
        let y = yOffset(for: start)
        let h = max(height(for: end.timeIntervalSince(start)), 26)

        return Button {
            onSelect(event)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(InfaceTheme.accent)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(event.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(InfaceTheme.textPrimary)
                            .lineLimit(h < 42 ? 1 : 2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        if event.isOngoing {
                            Text("сейчас")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(InfaceTheme.accent)
                        }
                    }
                    Text(timeRange(event))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(InfaceTheme.textSecondary)
                    if h >= 54 {
                        HStack(spacing: 6) {
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
                        .font(.caption2)
                        .foregroundStyle(InfaceTheme.textSecondary.opacity(0.9))
                    }
                }
                .padding(.vertical, 5)
                .padding(.trailing, 8)
            }
            .frame(maxWidth: .infinity, minHeight: h, maxHeight: h, alignment: .topLeading)
            .background(InfaceTheme.accent.opacity(event.isOngoing ? 0.22 : 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(InfaceTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .offset(y: y)
        .accessibilityHint("Показать подробности")
    }

    private var nowLine: some View {
        let y = yOffset(for: min(max(now, timeline.visibleStart), timeline.dayEnd))
        return HStack(spacing: 0) {
            Circle()
                .fill(InfaceTheme.danger)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(InfaceTheme.danger)
                .frame(height: 2)
        }
        .padding(.leading, gutterWidth - 4)
        .offset(y: y - 3)
        .accessibilityLabel("Сейчас")
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
