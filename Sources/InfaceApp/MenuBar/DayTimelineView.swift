import InfaceCore
import SwiftUI

struct DayTimelineView: View {
    let timeline: DayTimelineModel
    let now: Date
    let onSelect: (MeetingEvent) -> Void

    private let gutterWidth: CGFloat = 64
    private let columnSpacing: CGFloat = 4
    private let detector = MeetingLinkDetector.shared

    var body: some View {
        Group {
            if timeline.laidOutMeetings.isEmpty {
                Text("Нет встреч в этот день")
                    .font(.title3)
                    .foregroundStyle(InfaceTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 18)
            } else {
                GeometryReader { geo in
                    let hourHeight = computedHourHeight(availableHeight: geo.size.height)
                    let contentWidth = max(geo.size.width - gutterWidth - 16, 80)
                    ZStack(alignment: .topLeading) {
                        hourGrid(hourHeight: hourHeight)
                        meetingsLayer(hourHeight: hourHeight, contentWidth: contentWidth)
                        if timeline.isToday {
                            nowLine(hourHeight: hourHeight)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .padding(.trailing, 10)
                    .padding(.leading, 6)
                }
            }
        }
        .id(timeline.visibleStart.timeIntervalSince1970 + timeline.visibleEnd.timeIntervalSince1970)
    }

    private func computedHourHeight(availableHeight: CGFloat) -> CGFloat {
        let hours = max(timeline.visibleDuration / 3600.0, 0.25)
        return max(availableHeight / CGFloat(hours), 28)
    }

    private func hourGrid(hourHeight: CGFloat) -> some View {
        let hours = DayTimelineBuilder.hours(from: timeline.visibleStart, to: timeline.visibleEnd)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
                let y = yOffset(for: hour, hourHeight: hourHeight)
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

    private func meetingsLayer(hourHeight: CGFloat, contentWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(timeline.laidOutMeetings) { item in
                meetingBlock(item, hourHeight: hourHeight, contentWidth: contentWidth)
            }
        }
        .padding(.leading, gutterWidth)
    }

    private func meetingBlock(
        _ item: LaidOutMeeting,
        hourHeight: CGFloat,
        contentWidth: CGFloat
    ) -> some View {
        let event = item.event
        let start = max(event.startDate, timeline.visibleStart)
        let end = min(event.endDate, timeline.visibleEnd)
        let y = yOffset(for: start, hourHeight: hourHeight)
        let h = max(height(for: end.timeIntervalSince(start), hourHeight: hourHeight), 28)
        let isPast = timeline.isToday && event.endDate <= now

        let columns = CGFloat(item.columnCount)
        let totalSpacing = columnSpacing * max(columns - 1, 0)
        let columnWidth = max((contentWidth - totalSpacing) / columns, 40)
        let x = CGFloat(item.columnIndex) * (columnWidth + columnSpacing)

        return Button {
            onSelect(event)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(InfaceTheme.accent.opacity(isPast ? 0.45 : 1))
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(event.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(InfaceTheme.textPrimary.opacity(isPast ? 0.65 : 1))
                            .lineLimit(h < 48 ? 1 : 2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        if event.isOngoing {
                            Text("сейчас")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(InfaceTheme.accent)
                        }
                    }
                    if h >= 58, item.columnCount == 1 {
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
                .padding(.vertical, 6)
                .padding(.trailing, 8)
            }
            .frame(width: columnWidth, height: h, alignment: .topLeading)
            .background(InfaceTheme.accent.opacity(event.isOngoing ? 0.24 : (isPast ? 0.08 : 0.16)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(InfaceTheme.accent.opacity(isPast ? 0.2 : 0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
        .accessibilityHint("Показать подробности")
    }

    @ViewBuilder
    private func nowLine(hourHeight: CGFloat) -> some View {
        if now >= timeline.visibleStart && now <= timeline.visibleEnd {
            let y = yOffset(for: now, hourHeight: hourHeight)
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

    private func yOffset(for date: Date, hourHeight: CGFloat) -> CGFloat {
        let minutes = date.timeIntervalSince(timeline.visibleStart) / 60.0
        return CGFloat(max(minutes, 0)) * (hourHeight / 60.0)
    }

    private func height(for duration: TimeInterval, hourHeight: CGFloat) -> CGFloat {
        CGFloat(max(duration, 60) / 60.0) * (hourHeight / 60.0)
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
