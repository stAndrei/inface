import XCTest
@testable import InfaceCore

final class EWSResponseParserTests: XCTestCase {
    func testParseFindItemResponse() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
          <soap:Body>
            <m:FindItemResponse>
              <m:ResponseMessages>
                <m:FindItemResponseMessage ResponseClass="Success">
                  <m:RootFolder>
                    <t:Items>
                      <t:CalendarItem>
                        <t:ItemId Id="AAMkAGI1" ChangeKey="CQAA"/>
                        <t:Subject>Синк команды</t:Subject>
                        <t:Start>2026-08-11T09:00:00Z</t:Start>
                        <t:End>2026-08-11T10:00:00Z</t:End>
                        <t:Location>Zoom</t:Location>
                      </t:CalendarItem>
                    </t:Items>
                  </m:RootFolder>
                </m:FindItemResponseMessage>
              </m:ResponseMessages>
            </m:FindItemResponse>
          </soap:Body>
        </soap:Envelope>
        """
        let items = try EWSResponseParser.parseFindItemResponse(Data(xml.utf8))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, "AAMkAGI1")
        XCTAssertEqual(items[0].changeKey, "CQAA")
        XCTAssertEqual(items[0].title, "Синк команды")
        XCTAssertEqual(items[0].location, "Zoom")
    }

    func testParseGetItemWithBodyAndChatZone() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
          <soap:Body>
            <m:GetItemResponse>
              <m:ResponseMessages>
                <m:GetItemResponseMessage ResponseClass="Success">
                  <m:Items>
                    <t:CalendarItem>
                      <t:ItemId Id="AAMkAGI1"/>
                      <t:Subject>Daily</t:Subject>
                      <t:Start>2026-08-11T09:00:00Z</t:Start>
                      <t:End>2026-08-11T10:00:00Z</t:End>
                      <t:Location></t:Location>
                      <t:Body BodyType="Text">Созвон в ChatZone https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169</t:Body>
                    </t:CalendarItem>
                  </m:Items>
                </m:GetItemResponseMessage>
              </m:ResponseMessages>
            </m:GetItemResponse>
          </soap:Body>
        </soap:Envelope>
        """
        let items = try EWSResponseParser.parseGetItemResponse(Data(xml.utf8))
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].body?.contains("chatzone.o3t.ru") == true)
        let event = EWSResponseParser.mapToMeetingEvent(items[0])
        XCTAssertNotNil(event.notes)
        XCTAssertNotNil(event.url)
        XCTAssertEqual(event.url?.host, "chatzone.o3t.ru")
    }

    func testNormalizeHTMLBodyKeepsURL() {
        let html = #"<html><body><p>Join:</p><a href="https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169">meet</a></body></html>"#
        let notes = EWSBodyText.normalize(html)
        XCTAssertTrue(notes?.contains("chatzone.o3t.ru/meet/") == true)
    }

    func testMapToMeetingEvent() {
        let item = EWSCalendarItem(
            id: "1",
            title: "Demo",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3600),
            location: nil,
            body: "https://meet.google.com/abc-defg-hij"
        )
        let event = EWSResponseParser.mapToMeetingEvent(item)
        XCTAssertEqual(event.title, "Demo")
        XCTAssertNotNil(event.url)
        XCTAssertEqual(event.notes, "https://meet.google.com/abc-defg-hij")
    }

    func testFallbackUsername() {
        XCTAssertEqual(EWSClient.fallbackUsername(for: "petrovan@ozon.ru"), "o3\\petrovan")
    }

    func testEWSDateString() {
        let date = Date(timeIntervalSince1970: 0)
        let string = EWSRequestBuilder.ewsDateString(date)
        XCTAssertTrue(string.hasSuffix("Z"))
    }
}

final class MockEWSTransport: EWSHTTPTransport, @unchecked Sendable {
    var lastUsername: String?
    var lastPassword: String?
    var lastSoapAction: String?
    var responses: [EWSHTTPResponse] = []
    private var index = 0

    func post(
        url: URL,
        body: Data,
        username: String,
        password: String,
        soapAction: String
    ) async throws -> EWSHTTPResponse {
        lastUsername = username
        lastPassword = password
        lastSoapAction = soapAction
        guard index < responses.count else {
            throw EWSError.network("no mock")
        }
        defer { index += 1 }
        return responses[index]
    }
}

final class EWSClientTests: XCTestCase {
    func testUnauthorizedThrows() async {
        let transport = MockEWSTransport()
        transport.responses = [EWSHTTPResponse(statusCode: 401, body: Data())]
        let client = EWSClient(transport: transport)
        do {
            _ = try await client.fetchCalendarItems(
                endpoint: "https://mailsec.o3t.ru/EWS/Exchange.asmx",
                username: "petrovan@ozon.ru",
                password: "code:pass",
                from: Date(),
                to: Date().addingTimeInterval(3600)
            )
            XCTFail("expected unauthorized")
        } catch EWSError.unauthorized {
            XCTAssertEqual(transport.lastPassword, "code:pass")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testFindThenGetItemLoadsBody() async throws {
        let findXML = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
          <soap:Body>
            <m:FindItemResponse>
              <m:ResponseMessages>
                <m:FindItemResponseMessage ResponseClass="Success">
                  <m:RootFolder><t:Items>
                    <t:CalendarItem>
                      <t:ItemId Id="id1" ChangeKey="ck1"/>
                      <t:Subject>Test</t:Subject>
                      <t:Start>2026-08-11T09:00:00Z</t:Start>
                      <t:End>2026-08-11T10:00:00Z</t:End>
                    </t:CalendarItem>
                  </t:Items></m:RootFolder>
                </m:FindItemResponseMessage>
              </m:ResponseMessages>
            </m:FindItemResponse>
          </soap:Body>
        </soap:Envelope>
        """
        let getXML = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
          <soap:Body>
            <m:GetItemResponse>
              <m:ResponseMessages>
                <m:GetItemResponseMessage ResponseClass="Success">
                  <m:Items>
                    <t:CalendarItem>
                      <t:ItemId Id="id1" ChangeKey="ck1"/>
                      <t:Subject>Test</t:Subject>
                      <t:Start>2026-08-11T09:00:00Z</t:Start>
                      <t:End>2026-08-11T10:00:00Z</t:End>
                      <t:Body BodyType="Text">https://chatzone.o3t.ru/meet/6d54c167-7829-4d3e-80e8-3e0dd626b169</t:Body>
                    </t:CalendarItem>
                  </m:Items>
                </m:GetItemResponseMessage>
              </m:ResponseMessages>
            </m:GetItemResponse>
          </soap:Body>
        </soap:Envelope>
        """
        let transport = MockEWSTransport()
        transport.responses = [
            EWSHTTPResponse(statusCode: 200, body: Data(findXML.utf8)),
            EWSHTTPResponse(statusCode: 200, body: Data(getXML.utf8))
        ]
        let client = EWSClient(transport: transport)
        let items = try await client.fetchCalendarItems(
            endpoint: "https://mailsec.o3t.ru/EWS/Exchange.asmx",
            username: "petrovan@ozon.ru",
            password: "code:pass",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].body?.contains("chatzone") == true)
        XCTAssertEqual(transport.lastSoapAction, EWSRequestBuilder.soapActionGetItem)
    }

    func testFallbackOnUnauthorizedEmail() async throws {
        let findXML = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
          <soap:Body>
            <m:FindItemResponse>
              <m:ResponseMessages>
                <m:FindItemResponseMessage ResponseClass="Success">
                  <m:RootFolder><t:Items>
                    <t:CalendarItem>
                      <t:ItemId Id="id1"/>
                      <t:Subject>Test</t:Subject>
                      <t:Start>2026-08-11T09:00:00Z</t:Start>
                      <t:End>2026-08-11T10:00:00Z</t:End>
                    </t:CalendarItem>
                  </t:Items></m:RootFolder>
                </m:FindItemResponseMessage>
              </m:ResponseMessages>
            </m:FindItemResponse>
          </soap:Body>
        </soap:Envelope>
        """
        let getXML = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
                       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
          <soap:Body>
            <m:GetItemResponse>
              <m:ResponseMessages>
                <m:GetItemResponseMessage ResponseClass="Success">
                  <m:Items>
                    <t:CalendarItem>
                      <t:ItemId Id="id1"/>
                      <t:Subject>Test</t:Subject>
                      <t:Start>2026-08-11T09:00:00Z</t:Start>
                      <t:End>2026-08-11T10:00:00Z</t:End>
                      <t:Body BodyType="Text">ok</t:Body>
                    </t:CalendarItem>
                  </m:Items>
                </m:GetItemResponseMessage>
              </m:ResponseMessages>
            </m:GetItemResponse>
          </soap:Body>
        </soap:Envelope>
        """
        let transport = MockEWSTransport()
        transport.responses = [
            EWSHTTPResponse(statusCode: 401, body: Data()),
            EWSHTTPResponse(statusCode: 200, body: Data(findXML.utf8)),
            EWSHTTPResponse(statusCode: 200, body: Data(getXML.utf8))
        ]
        let service = EWSCalendarService(
            endpoint: "https://mailsec.o3t.ru/EWS/Exchange.asmx",
            username: "petrovan@ozon.ru",
            credentialStore: MockExchangeCredentialStore(),
            client: EWSClient(transport: transport)
        )
        try await service.login(
            username: "petrovan@ozon.ru",
            password: "code:pass",
            endpoint: "https://mailsec.o3t.ru/EWS/Exchange.asmx"
        )
        XCTAssertEqual(transport.lastUsername, "o3\\petrovan")
    }
}

final class CalendarSourceRouterTests: XCTestCase {
    func testSwitchesSource() async {
        let exchange = EWSCalendarService(credentialStore: MockExchangeCredentialStore())
        let router = CalendarSourceRouter(
            source: .eventKit,
            eventKit: MockCalendarService(authorizationStatus: .authorized),
            exchange: exchange
        )
        router.setSource(.exchange)
        XCTAssertEqual(router.activeSource, .exchange)
    }
}

final class ExchangeCredentialStoreTests: XCTestCase {
    func testMockStoreRoundTrip() throws {
        let store = MockExchangeCredentialStore()
        try store.savePassword("code:secret", for: "petrovan@ozon.ru")
        XCTAssertTrue(store.hasCredentials(for: "petrovan@ozon.ru"))
        XCTAssertEqual(try store.loadPassword(for: "petrovan@ozon.ru"), "code:secret")
        try store.deletePassword(for: "petrovan@ozon.ru")
        XCTAssertFalse(store.hasCredentials(for: "petrovan@ozon.ru"))
    }
}

final class EWSErrorLocalizedTests: XCTestCase {
    func testUnauthorizedMessage() {
        let message = EWSErrorLocalized.message(for: EWSError.unauthorized)
        XCTAssertTrue(message.contains("@mail-bot"))
    }
}
