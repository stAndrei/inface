import Foundation

public enum EWSError: Error, Equatable, Sendable {
    case invalidEndpoint
    case unauthorized
    case network(String)
    case server(Int)
    case parseFailure
    case missingCredentials
}

public struct EWSHTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol EWSHTTPTransport: Sendable {
    func post(url: URL, body: Data, username: String, password: String) async throws -> EWSHTTPResponse
}

public struct URLSessionEWSTransport: EWSHTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func post(url: URL, body: Data, username: String, password: String) async throws -> EWSHTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(EWSRequestBuilder.soapActionFindItem, forHTTPHeaderField: "SOAPAction")
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw EWSError.network("Некорректный ответ сервера")
            }
            return EWSHTTPResponse(statusCode: http.statusCode, body: data)
        } catch let error as EWSError {
            throw error
        } catch {
            throw EWSError.network(error.localizedDescription)
        }
    }
}

public enum EWSRequestBuilder {
    public static let soapActionFindItem = "http://schemas.microsoft.com/exchange/services/2006/messages/FindItem"

    public static func findItemRequest(start: Date, end: Date) -> Data {
        let startString = ewsDateString(start)
        let endString = ewsDateString(end)
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header>
            <t:RequestServerVersion Version="Exchange2013"/>
          </soap:Header>
          <soap:Body>
            <m:FindItem Traversal="Shallow">
              <m:ItemShape>
                <t:BaseShape>Default</t:BaseShape>
                <t:BodyType>Text</t:BodyType>
              </m:ItemShape>
              <m:CalendarView MaxEntriesReturned="200" StartDate="\(startString)" EndDate="\(endString)"/>
              <m:ParentFolderIds>
                <t:DistinguishedFolderId Id="calendar"/>
              </m:ParentFolderIds>
            </m:FindItem>
          </soap:Body>
        </soap:Envelope>
        """
        return Data(xml.utf8)
    }

    public static func ewsDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

public struct EWSClient: Sendable {
    public let transport: EWSHTTPTransport

    public init(transport: EWSHTTPTransport = URLSessionEWSTransport()) {
        self.transport = transport
    }

    public func fetchCalendarItems(
        endpoint: String,
        username: String,
        password: String,
        from start: Date,
        to end: Date
    ) async throws -> [EWSCalendarItem] {
        guard let url = URL(string: endpoint) else {
            throw EWSError.invalidEndpoint
        }
        let body = EWSRequestBuilder.findItemRequest(start: start, end: end)
        let response = try await transport.post(url: url, body: body, username: username, password: password)
        switch response.statusCode {
        case 200:
            return try EWSResponseParser.parseFindItemResponse(response.body)
        case 401:
            throw EWSError.unauthorized
        default:
            throw EWSError.server(response.statusCode)
        }
    }

    public static func fallbackUsername(for emailUsername: String) -> String {
        let login = emailUsername.split(separator: "@").first.map(String.init) ?? emailUsername
        return "o3\\\(login)"
    }
}

public struct EWSCalendarItem: Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let body: String?
}

public enum EWSResponseParser {
    private static let messagesNS = "http://schemas.microsoft.com/exchange/services/2006/messages"
    private static let typesNS = "http://schemas.microsoft.com/exchange/services/2006/types"

    public static func parseFindItemResponse(_ data: Data) throws -> [EWSCalendarItem] {
        let delegate = FindItemParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw EWSError.parseFailure
        }
        return delegate.items
    }

    public static func mapToMeetingEvent(_ item: EWSCalendarItem) -> MeetingEvent {
        var url: URL?
        if let body = item.body, let detected = MeetingLinkDetector.shared.detect(in: body) {
            url = detected
        } else if let location = item.location, let detected = MeetingLinkDetector.shared.detect(in: location) {
            url = detected
        }
        return MeetingEvent(
            id: item.id,
            title: item.title.isEmpty ? "Без названия" : item.title,
            startDate: item.startDate,
            endDate: item.endDate,
            calendarId: "exchange",
            calendarTitle: "Exchange",
            notes: item.body,
            url: url,
            location: item.location
        )
    }
}

private final class FindItemParserDelegate: NSObject, XMLParserDelegate {
    var items: [EWSCalendarItem] = []

    private var inCalendarItem = false
    private var currentElement = ""
    private var currentText = ""

    private var itemId = ""
    private var subject = ""
    private var startDate: Date?
    private var endDate: Date?
    private var location: String?
    private var body: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = Self.localName(elementName)
        currentElement = name
        currentText = ""
        if name == "CalendarItem" {
            inCalendarItem = true
            itemId = ""
            subject = ""
            startDate = nil
            endDate = nil
            location = nil
            body = nil
        } else if inCalendarItem, name == "ItemId", let id = attributeDict["Id"] {
            itemId = id
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard inCalendarItem else { return }
        let name = Self.localName(elementName)
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "Subject":
            subject = trimmed
        case "Start":
            startDate = parseEWSDate(trimmed)
        case "End":
            endDate = parseEWSDate(trimmed)
        case "Location":
            location = trimmed.isEmpty ? nil : trimmed
        case "Body":
            body = trimmed.isEmpty ? nil : trimmed
        case "CalendarItem":
            if let start = startDate, let end = endDate, !itemId.isEmpty {
                items.append(EWSCalendarItem(
                    id: itemId,
                    title: subject,
                    startDate: start,
                    endDate: end,
                    location: location,
                    body: body
                ))
            }
            inCalendarItem = false
        default:
            break
        }
        currentText = ""
    }

    private static func localName(_ elementName: String) -> String {
        if let colon = elementName.firstIndex(of: ":") {
            return String(elementName[elementName.index(after: colon)...])
        }
        return elementName
    }

    private func parseEWSDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

extension MeetingLinkDetector {
    func detect(in text: String) -> URL? {
        let event = MeetingEvent(
            id: "tmp",
            title: "",
            startDate: Date(),
            endDate: Date(),
            calendarId: "",
            calendarTitle: "",
            notes: text
        )
        return detect(in: event)
    }
}
