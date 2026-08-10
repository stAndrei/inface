import Foundation

public struct DayTimelineInterval: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case meeting(MeetingEvent)
    }

    public let id: String
    public let start: Date
    public let end: Date
    public let kind: Kind

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(id: String, start: Date, end: Date, kind: Kind) {
        self.id = id
        self.start = start
        self.end = end
        self.kind = kind
    }
}

public struct DayTimelineModel: Equatable, Sendable {
    public let dayStart: Date
    public let dayEnd: Date
    public let visibleStart: Date
    public let visibleEnd: Date
    public let intervals: [DayTimelineInterval]
    public let meetings: [MeetingEvent]
    public let isToday: Bool

    public init(
        dayStart: Date,
        dayEnd: Date,
        visibleStart: Date,
        visibleEnd: Date,
        intervals: [DayTimelineInterval],
        meetings: [MeetingEvent],
        isToday: Bool
    ) {
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.visibleStart = visibleStart
        self.visibleEnd = visibleEnd
        self.intervals = intervals
        self.meetings = meetings
        self.isToday = isToday
    }

    public var visibleDuration: TimeInterval {
        max(visibleEnd.timeIntervalSince(visibleStart), 60)
    }
}

public enum DayTimelineBuilder {
    /// Timeline spans only from the first to the last meeting of the day.
    public static func build(
        events: [MeetingEvent],
        day: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DayTimelineModel {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        let isToday = calendar.isDate(dayStart, inSameDayAs: now)

        let meetings = events
            .filter { $0.startDate < dayEnd && $0.endDate > dayStart }
            .map { event in
                MeetingEvent(
                    id: event.id,
                    title: event.title,
                    startDate: max(event.startDate, dayStart),
                    endDate: min(event.endDate, dayEnd),
                    calendarId: event.calendarId,
                    calendarTitle: event.calendarTitle,
                    notes: event.notes,
                    url: event.url,
                    location: event.location
                )
            }
            .filter { $0.endDate > $0.startDate }
            .sorted { $0.startDate < $1.startDate }

        guard let first = meetings.first, let last = meetings.last else {
            return DayTimelineModel(
                dayStart: dayStart,
                dayEnd: dayEnd,
                visibleStart: dayStart,
                visibleEnd: dayStart.addingTimeInterval(60),
                intervals: [],
                meetings: [],
                isToday: isToday
            )
        }

        let visibleStart = first.startDate
        let visibleEnd = max(last.endDate, visibleStart.addingTimeInterval(60))

        let intervals = meetings.map { meeting in
            DayTimelineInterval(
                id: "meeting-\(meeting.id)",
                start: meeting.startDate,
                end: meeting.endDate,
                kind: .meeting(meeting)
            )
        }

        return DayTimelineModel(
            dayStart: dayStart,
            dayEnd: dayEnd,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            intervals: intervals,
            meetings: meetings,
            isToday: isToday
        )
    }

    /// Hour marks strictly inside `(start, end]` plus the hour of `start` when it falls on an hour.
    public static func hours(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        guard var cursor = calendar.date(from: components) else { return [] }
        if cursor < start {
            cursor = calendar.date(byAdding: .hour, value: 1, to: cursor) ?? cursor
        }
        while cursor <= end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
