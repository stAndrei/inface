import Foundation

public struct DayTimelineInterval: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case free
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
    public let intervals: [DayTimelineInterval]
    public let meetings: [MeetingEvent]
    public let isToday: Bool

    public init(
        dayStart: Date,
        dayEnd: Date,
        visibleStart: Date,
        intervals: [DayTimelineInterval],
        meetings: [MeetingEvent],
        isToday: Bool
    ) {
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.visibleStart = visibleStart
        self.intervals = intervals
        self.meetings = meetings
        self.isToday = isToday
    }

    public var visibleDuration: TimeInterval {
        max(dayEnd.timeIntervalSince(visibleStart), 60)
    }
}

public enum DayTimelineBuilder {
    /// Builds a day timeline for `day`, with free gaps between meetings.
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

        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        let firstMeetingStart = meetings.map(\.startDate).min()
        var visibleStart = workdayStart
        if let firstMeetingStart {
            visibleStart = min(workdayStart, firstMeetingStart)
        }
        visibleStart = max(visibleStart, dayStart)

        var cursor = visibleStart
        var intervals: [DayTimelineInterval] = []

        for meeting in meetings {
            let meetingStart = max(meeting.startDate, visibleStart)
            let meetingEnd = max(meeting.endDate, meetingStart)
            if meetingStart > cursor {
                intervals.append(
                    DayTimelineInterval(
                        id: "free-\(cursor.timeIntervalSince1970)-\(meeting.id)",
                        start: cursor,
                        end: meetingStart,
                        kind: .free
                    )
                )
            }
            intervals.append(
                DayTimelineInterval(
                    id: "meeting-\(meeting.id)",
                    start: meetingStart,
                    end: meetingEnd,
                    kind: .meeting(meeting)
                )
            )
            cursor = max(cursor, meetingEnd)
        }

        if cursor < dayEnd {
            intervals.append(
                DayTimelineInterval(
                    id: "free-end-\(cursor.timeIntervalSince1970)",
                    start: cursor,
                    end: dayEnd,
                    kind: .free
                )
            )
        }

        return DayTimelineModel(
            dayStart: dayStart,
            dayEnd: dayEnd,
            visibleStart: visibleStart,
            intervals: intervals,
            meetings: meetings,
            isToday: isToday
        )
    }

    public static func hours(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        guard var cursor = calendar.date(from: components) else { return [] }
        if cursor < start {
            cursor = calendar.date(byAdding: .hour, value: 1, to: cursor) ?? cursor
        }
        while cursor < end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
