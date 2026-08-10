import Foundation

public struct MeetingEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var calendarId: String
    public var calendarTitle: String
    public var notes: String?
    public var url: URL?
    public var location: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarId: String,
        calendarTitle: String,
        notes: String? = nil,
        url: URL? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarId = calendarId
        self.calendarTitle = calendarTitle
        self.notes = notes
        self.url = url
        self.location = location
    }

    public var isOngoing: Bool {
        let now = Date()
        return startDate <= now && endDate > now
    }
}
