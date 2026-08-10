import Foundation

public struct LaidOutMeeting: Equatable, Sendable, Identifiable {
    public var id: String { event.id }
    public let event: MeetingEvent
    public let columnIndex: Int
    public let columnCount: Int

    public init(event: MeetingEvent, columnIndex: Int, columnCount: Int) {
        self.event = event
        self.columnIndex = columnIndex
        self.columnCount = max(columnCount, 1)
    }
}

public struct DayTimelineModel: Equatable, Sendable {
    public let dayStart: Date
    public let dayEnd: Date
    public let visibleStart: Date
    public let visibleEnd: Date
    public let laidOutMeetings: [LaidOutMeeting]
    public let isToday: Bool

    public var meetings: [MeetingEvent] { laidOutMeetings.map(\.event) }

    public init(
        dayStart: Date,
        dayEnd: Date,
        visibleStart: Date,
        visibleEnd: Date,
        laidOutMeetings: [LaidOutMeeting],
        isToday: Bool
    ) {
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.visibleStart = visibleStart
        self.visibleEnd = visibleEnd
        self.laidOutMeetings = laidOutMeetings
        self.isToday = isToday
    }

    public var visibleDuration: TimeInterval {
        max(visibleEnd.timeIntervalSince(visibleStart), 60)
    }
}

public enum DayTimelineBuilder {
    /// Timeline spans only from the first to the last meeting of the day.
    /// Overlapping meetings get Calendar-like column layout.
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
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.endDate > $1.endDate
            }

        guard let first = meetings.first, let lastByEnd = meetings.max(by: { $0.endDate < $1.endDate }) else {
            return DayTimelineModel(
                dayStart: dayStart,
                dayEnd: dayEnd,
                visibleStart: dayStart,
                visibleEnd: dayStart.addingTimeInterval(60),
                laidOutMeetings: [],
                isToday: isToday
            )
        }

        let visibleStart = first.startDate
        let visibleEnd = max(lastByEnd.endDate, visibleStart.addingTimeInterval(60))
        let laidOut = layoutColumns(for: meetings)

        return DayTimelineModel(
            dayStart: dayStart,
            dayEnd: dayEnd,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            laidOutMeetings: laidOut,
            isToday: isToday
        )
    }

    /// Assigns side-by-side columns for overlapping meetings (Mac Calendar style).
    public static func layoutColumns(for meetings: [MeetingEvent]) -> [LaidOutMeeting] {
        guard !meetings.isEmpty else { return [] }

        let sorted = meetings.sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.endDate > $1.endDate
        }

        var result: [LaidOutMeeting] = []
        var index = 0
        while index < sorted.count {
            var cluster: [MeetingEvent] = [sorted[index]]
            var clusterEnd = sorted[index].endDate
            var next = index + 1
            while next < sorted.count, sorted[next].startDate < clusterEnd {
                cluster.append(sorted[next])
                clusterEnd = max(clusterEnd, sorted[next].endDate)
                next += 1
            }

            result.append(contentsOf: packCluster(cluster))
            index = next
        }
        return result
    }

    private static func packCluster(_ cluster: [MeetingEvent]) -> [LaidOutMeeting] {
        let ordered = cluster.sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.endDate > $1.endDate
        }

        var columnEnds: [Date] = []
        var placements: [(MeetingEvent, Int)] = []

        for event in ordered {
            if let column = columnEnds.firstIndex(where: { $0 <= event.startDate }) {
                columnEnds[column] = event.endDate
                placements.append((event, column))
            } else {
                columnEnds.append(event.endDate)
                placements.append((event, columnEnds.count - 1))
            }
        }

        let columnCount = max(columnEnds.count, 1)
        return placements.map { LaidOutMeeting(event: $0.0, columnIndex: $0.1, columnCount: columnCount) }
    }

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
