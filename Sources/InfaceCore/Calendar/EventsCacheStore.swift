import Foundation

public protocol EventsCaching: Sendable {
    func load(source: CalendarSource) -> [MeetingEvent]
    func save(_ events: [MeetingEvent], source: CalendarSource)
    func clear(source: CalendarSource)
}

public final class EventsCacheStore: EventsCaching, @unchecked Sendable {
    private let fileManager: FileManager
    private let directory: URL

    public init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directory = base.appendingPathComponent("Inface", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func load(source: CalendarSource) -> [MeetingEvent] {
        let url = fileURL(for: source)
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(CachePayload.self, from: data)
        else {
            return []
        }
        return decoded.events
    }

    public func save(_ events: [MeetingEvent], source: CalendarSource) {
        let payload = CachePayload(events: events, savedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL(for: source), options: .atomic)
    }

    public func clear(source: CalendarSource) {
        try? fileManager.removeItem(at: fileURL(for: source))
    }

    private func fileURL(for source: CalendarSource) -> URL {
        // v2: Exchange events include Body/notes from GetItem.
        let version = source == .exchange ? "v2" : "v1"
        return directory.appendingPathComponent("events-\(source.rawValue)-\(version).json")
    }
}

public final class InMemoryEventsCache: EventsCaching, @unchecked Sendable {
    private var storage: [CalendarSource: [MeetingEvent]] = [:]

    public init() {}

    public func load(source: CalendarSource) -> [MeetingEvent] {
        storage[source] ?? []
    }

    public func save(_ events: [MeetingEvent], source: CalendarSource) {
        storage[source] = events
    }

    public func clear(source: CalendarSource) {
        storage.removeValue(forKey: source)
    }
}

private struct CachePayload: Codable {
    let events: [MeetingEvent]
    let savedAt: Date
}
