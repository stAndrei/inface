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
    func post(
        url: URL,
        body: Data,
        username: String,
        password: String,
        soapAction: String
    ) async throws -> EWSHTTPResponse
}

public struct URLSessionEWSTransport: EWSHTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func post(
        url: URL,
        body: Data,
        username: String,
        password: String,
        soapAction: String
    ) async throws -> EWSHTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 60
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(soapAction, forHTTPHeaderField: "SOAPAction")
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
    public static let soapActionFindItem =
        "http://schemas.microsoft.com/exchange/services/2006/messages/FindItem"
    public static let soapActionGetItem =
        "http://schemas.microsoft.com/exchange/services/2006/messages/GetItem"

    public static func findItemRequest(start: Date, end: Date) -> Data {
        let startString = ewsDateString(start)
        let endString = ewsDateString(end)
        // FindItem never returns Body — only IDs + summary. Details come from GetItem.
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
                <t:BaseShape>IdOnly</t:BaseShape>
                <t:AdditionalProperties>
                  <t:FieldURI FieldURI="item:Subject"/>
                  <t:FieldURI FieldURI="calendar:Start"/>
                  <t:FieldURI FieldURI="calendar:End"/>
                  <t:FieldURI FieldURI="calendar:Location"/>
                </t:AdditionalProperties>
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

    public static func getItemRequest(ids: [(id: String, changeKey: String?)]) -> Data {
        let itemIds = ids.map { pair -> String in
            if let changeKey = pair.changeKey, !changeKey.isEmpty {
                return #"<t:ItemId Id="\#(xmlEscape(pair.id))" ChangeKey="\#(xmlEscape(changeKey))"/>"#
            }
            return #"<t:ItemId Id="\#(xmlEscape(pair.id))"/>"#
        }.joined(separator: "\n")

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
            <m:GetItem>
              <m:ItemShape>
                <t:BaseShape>Default</t:BaseShape>
                <t:BodyType>Text</t:BodyType>
                <t:AdditionalProperties>
                  <t:FieldURI FieldURI="item:Body"/>
                  <t:FieldURI FieldURI="item:TextBody"/>
                  <t:FieldURI FieldURI="item:Subject"/>
                  <t:FieldURI FieldURI="calendar:Location"/>
                  <t:FieldURI FieldURI="calendar:Start"/>
                  <t:FieldURI FieldURI="calendar:End"/>
                </t:AdditionalProperties>
              </m:ItemShape>
              <m:ItemIds>
                \(itemIds)
              </m:ItemIds>
            </m:GetItem>
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

    public static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

public struct EWSClient: Sendable {
    public let transport: EWSHTTPTransport
    public let getItemBatchSize: Int

    public init(transport: EWSHTTPTransport = URLSessionEWSTransport(), getItemBatchSize: Int = 40) {
        self.transport = transport
        self.getItemBatchSize = max(1, getItemBatchSize)
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

        let findBody = EWSRequestBuilder.findItemRequest(start: start, end: end)
        let findResponse = try await transport.post(
            url: url,
            body: findBody,
            username: username,
            password: password,
            soapAction: EWSRequestBuilder.soapActionFindItem
        )
        switch findResponse.statusCode {
        case 200:
            break
        case 401:
            throw EWSError.unauthorized
        default:
            throw EWSError.server(findResponse.statusCode)
        }

        let summaries = try EWSResponseParser.parseFindItemResponse(findResponse.body)
        guard !summaries.isEmpty else { return [] }

        var detailed: [EWSCalendarItem] = []
        detailed.reserveCapacity(summaries.count)

        for batch in summaries.chunked(into: getItemBatchSize) {
            let ids = batch.map { (id: $0.id, changeKey: $0.changeKey) }
            let getBody = EWSRequestBuilder.getItemRequest(ids: ids)
            let getResponse = try await transport.post(
                url: url,
                body: getBody,
                username: username,
                password: password,
                soapAction: EWSRequestBuilder.soapActionGetItem
            )
            switch getResponse.statusCode {
            case 200:
                let items = try EWSResponseParser.parseGetItemResponse(getResponse.body)
                if items.isEmpty {
                    // Fallback to FindItem summary if GetItem shape is restricted.
                    detailed.append(contentsOf: batch)
                } else {
                    let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
                    for summary in batch {
                        if let full = byId[summary.id] {
                            detailed.append(merge(summary: summary, detail: full))
                        } else {
                            detailed.append(summary)
                        }
                    }
                }
            case 401:
                throw EWSError.unauthorized
            default:
                // Keep summary data rather than failing the whole window.
                detailed.append(contentsOf: batch)
            }
        }

        return detailed.sorted { $0.startDate < $1.startDate }
    }

    public static func fallbackUsername(for emailUsername: String) -> String {
        let login = emailUsername.split(separator: "@").first.map(String.init) ?? emailUsername
        return "o3\\\(login)"
    }

    private func merge(summary: EWSCalendarItem, detail: EWSCalendarItem) -> EWSCalendarItem {
        EWSCalendarItem(
            id: detail.id.isEmpty ? summary.id : detail.id,
            changeKey: detail.changeKey ?? summary.changeKey,
            title: detail.title.isEmpty ? summary.title : detail.title,
            startDate: detail.startDate,
            endDate: detail.endDate,
            location: detail.location ?? summary.location,
            body: detail.body ?? summary.body
        )
    }
}

public struct EWSCalendarItem: Equatable, Sendable {
    public let id: String
    public let changeKey: String?
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let body: String?

    public init(
        id: String,
        changeKey: String? = nil,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        body: String?
    ) {
        self.id = id
        self.changeKey = changeKey
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.body = body
    }
}

public enum EWSResponseParser {
    public static func parseFindItemResponse(_ data: Data) throws -> [EWSCalendarItem] {
        try parseCalendarItems(data)
    }

    public static func parseGetItemResponse(_ data: Data) throws -> [EWSCalendarItem] {
        try parseCalendarItems(data)
    }

    public static func mapToMeetingEvent(_ item: EWSCalendarItem) -> MeetingEvent {
        let notes = item.body.flatMap { EWSBodyText.normalize($0) }
        var url: URL?
        if let notes, let detected = MeetingLinkDetector.shared.detect(in: notes) {
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
            notes: notes,
            url: url,
            location: item.location
        )
    }

    private static func parseCalendarItems(_ data: Data) throws -> [EWSCalendarItem] {
        let delegate = CalendarItemParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        guard parser.parse() else {
            throw EWSError.parseFailure
        }
        return delegate.items
    }
}

public enum EWSBodyText {
    /// Turns HTML/text body into readable notes while keeping URLs for link detection.
    public static func normalize(_ raw: String) -> String? {
        let hrefURLs = extractHREFURLs(from: raw)
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if text.localizedCaseInsensitiveContains("<html")
            || text.localizedCaseInsensitiveContains("<body")
            || text.contains("<p")
            || text.contains("<br")
            || text.contains("<div")
            || text.contains("<a")
        {
            text = text.replacingOccurrences(
                of: #"(?i)<br\s*/?>"#,
                with: "\n",
                options: .regularExpression
            )
            text = text.replacingOccurrences(
                of: #"(?i)</p>"#,
                with: "\n",
                options: .regularExpression
            )
            text = text.replacingOccurrences(
                of: #"<[^>]+>"#,
                with: " ",
                options: .regularExpression
            )
        }
        text = decodeHTMLEntities(text)
        text = text
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for url in hrefURLs where !text.contains(url) {
            text = text.isEmpty ? url : text + "\n" + url
        }

        return text.isEmpty ? nil : text
    }

    public static func extractHREFURLs(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"href\s*=\s*["']([^"']+)["']"#,
            options: .caseInsensitive
        ) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let swiftRange = Range(match.range(at: 1), in: html)
            else {
                return nil
            }
            return String(html[swiftRange])
        }
    }

    public static func decodeHTMLEntities(_ text: String) -> String {
        // Avoid AppKit HTML importer (slow / main-thread); decode common entities only.
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

private final class CalendarItemParserDelegate: NSObject, XMLParserDelegate {
    var items: [EWSCalendarItem] = []

    private var inCalendarItem = false
    private var currentText = ""
    private var capturingText = false

    private var itemId = ""
    private var changeKey: String?
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
        currentText = ""
        capturingText = false

        if name == "CalendarItem" {
            inCalendarItem = true
            itemId = ""
            changeKey = nil
            subject = ""
            startDate = nil
            endDate = nil
            location = nil
            body = nil
        } else if inCalendarItem, name == "ItemId" {
            if let id = attributeDict["Id"] {
                itemId = id
            }
            changeKey = attributeDict["ChangeKey"]
        } else if inCalendarItem {
            switch name {
            case "Subject", "Start", "End", "Location", "Body", "TextBody":
                capturingText = true
            default:
                break
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard capturingText else { return }
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard capturingText, let string = String(data: CDATABlock, encoding: .utf8) else { return }
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
        case "Body", "TextBody":
            if !trimmed.isEmpty {
                // Prefer TextBody when both present; Body may arrive as HTML.
                if name == "TextBody" || body == nil {
                    body = trimmed
                }
            }
        case "CalendarItem":
            if let start = startDate, let end = endDate, !itemId.isEmpty {
                items.append(EWSCalendarItem(
                    id: itemId,
                    changeKey: changeKey,
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
        capturingText = false
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<next]))
            index = next
        }
        return result
    }
}
