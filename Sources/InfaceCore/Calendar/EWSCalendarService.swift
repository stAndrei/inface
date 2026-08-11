import Foundation

public final class EWSCalendarService: CalendarAccessing, @unchecked Sendable {
    public private(set) var endpoint: String
    public private(set) var username: String
    private let credentialStore: ExchangeCredentialStoring
    private let client: EWSClient
    private var pollTimer: Timer?
    private var changeHandler: (@Sendable () -> Void)?
    private var authFailed = false

    public init(
        endpoint: String = AppSettings.defaultExchangeEndpoint,
        username: String = "",
        credentialStore: ExchangeCredentialStoring = ExchangeCredentialStore(),
        client: EWSClient = EWSClient()
    ) {
        self.endpoint = endpoint
        self.username = username
        self.credentialStore = credentialStore
        self.client = client
    }

    deinit {
        stopObservingChanges()
    }

    public var authorizationStatus: CalendarAuthStatus {
        guard !username.isEmpty else { return .notDetermined }
        if authFailed { return .denied }
        return credentialStore.hasCredentials(for: username) ? .authorized : .notDetermined
    }

    public func configure(endpoint: String, username: String) {
        self.endpoint = endpoint
        self.username = username
        authFailed = false
    }

    public func requestAccess() async -> Bool {
        authorizationStatus == .authorized
    }

    public func login(username: String, password: String, endpoint: String) async throws {
        self.endpoint = endpoint
        self.username = username
        authFailed = false
        let start = Date()
        let end = start.addingTimeInterval(3600)
        _ = try await fetchWithFallback(username: username, password: password, from: start, to: end)
        try credentialStore.savePassword(password, for: username)
    }

    public func logout() throws {
        if !username.isEmpty {
            try credentialStore.deletePassword(for: username)
        }
        authFailed = false
    }

    public func fetchEvents(from start: Date, to end: Date) throws -> [MeetingEvent] {
        guard !username.isEmpty else { throw EWSError.missingCredentials }
        guard let password = try? credentialStore.loadPassword(for: username) else {
            throw EWSError.missingCredentials
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[MeetingEvent], Error> = .failure(EWSError.network("Не удалось загрузить события"))
        Task {
            do {
                let items = try await fetchWithFallback(username: username, password: password, from: start, to: end)
                let events = items.map(EWSResponseParser.mapToMeetingEvent).sorted { $0.startDate < $1.startDate }
                result = .success(events)
            } catch {
                if case EWSError.unauthorized = error {
                    authFailed = true
                }
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try result.get()
    }

    public func fetchEventsAsync(from start: Date, to end: Date) async throws -> [MeetingEvent] {
        guard !username.isEmpty else { throw EWSError.missingCredentials }
        guard let password = try? credentialStore.loadPassword(for: username) else {
            throw EWSError.missingCredentials
        }
        do {
            let items = try await fetchWithFallback(username: username, password: password, from: start, to: end)
            authFailed = false
            return items.map(EWSResponseParser.mapToMeetingEvent).sorted { $0.startDate < $1.startDate }
        } catch {
            if case EWSError.unauthorized = error {
                authFailed = true
            }
            throw error
        }
    }

    public func startObservingChanges(_ handler: @escaping @Sendable () -> Void) {
        stopObservingChanges()
        changeHandler = handler
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.changeHandler?()
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
    }

    public func stopObservingChanges() {
        pollTimer?.invalidate()
        pollTimer = nil
        changeHandler = nil
    }

    private func fetchWithFallback(
        username: String,
        password: String,
        from start: Date,
        to end: Date
    ) async throws -> [EWSCalendarItem] {
        do {
            return try await client.fetchCalendarItems(
                endpoint: endpoint,
                username: username,
                password: password,
                from: start,
                to: end
            )
        } catch EWSError.unauthorized where username.contains("@") {
            let fallback = EWSClient.fallbackUsername(for: username)
            return try await client.fetchCalendarItems(
                endpoint: endpoint,
                username: fallback,
                password: password,
                from: start,
                to: end
            )
        }
    }
}

public enum EWSErrorLocalized {
    public static func message(for error: Error) -> String {
        switch error {
        case EWSError.unauthorized:
            return "Неверный логин или пароль. Проверьте формат код:пароль из @mail-bot."
        case EWSError.missingCredentials:
            return "Войдите в Exchange в настройках Inface."
        case EWSError.invalidEndpoint:
            return "Некорректный адрес сервера Exchange."
        case EWSError.parseFailure:
            return "Не удалось разобрать ответ сервера Exchange."
        case let EWSError.network(message):
            return "Ошибка сети: \(message)"
        case let EWSError.server(code):
            return "Сервер Exchange вернул ошибку (\(code))."
        default:
            return error.localizedDescription
        }
    }
}
