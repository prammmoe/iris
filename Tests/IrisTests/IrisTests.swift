import Testing
import Foundation
@testable import Iris

@Suite(.serialized)
struct IrisTests {
    @Test func canInitOnlyAcceptsHTTPAndHTTPS() async throws {
        await resetIris()
        Iris.start()
        
        #expect(IrisURLProtocol.canInit(with: request("http://example.com")))
        #expect(IrisURLProtocol.canInit(with: request("https://example.com")))
        #expect(!IrisURLProtocol.canInit(with: request("ftp://example.com")))
        #expect(!IrisURLProtocol.canInit(with: request("file:///tmp/iris.txt")))
    }
    
    @Test func canInitRejectsAlreadyHandledRequest() async throws {
        await resetIris()
        Iris.start()
        
        let mutableRequest = NSMutableURLRequest(url: URL(string: "https://example.com")!)
        URLProtocol.setProperty(true, forKey: "com.iris.request-handled", in: mutableRequest)
        
        #expect(!IrisURLProtocol.canInit(with: mutableRequest as URLRequest))
    }
    
    @Test func canInitRejectsIgnoredHost() async throws {
        await resetIris()
        
        Iris.start(
            configuration: IrisConfiguration(ignoredHosts: ["EXAMPLE.com"])
        )
        
        #expect(!IrisURLProtocol.canInit(with: request("https://example.com")))
        #expect(IrisURLProtocol.canInit(with: request("https://api.example.com")))
    }
    
    @Test func headersAreVisibleByDefault() {
        let redacted = IrisRedactor.headers(
            [
                "Authorization": "Bearer token",
                "Cookie": "session=abc",
                "Content-Type": "application/json"
            ],
            redactedNames: IrisConfiguration().redactedHeaders
        )
        
        #expect(redacted["Authorization"] == "Bearer token")
        #expect(redacted["Cookie"] == "session=abc")
        #expect(redacted["Content-Type"] == "application/json")
    }
    
    @Test func configuredSensitiveHeadersAreRedacted() {
        let redacted = IrisRedactor.headers(
            [
                "Authorization": "Bearer token",
                "Cookie": "session=abc",
                "Content-Type": "application/json"
            ],
            redactedNames: ["authorization", "cookie"]
        )
        
        #expect(redacted["Authorization"] == "<redacted>")
        #expect(redacted["Cookie"] == "<redacted>")
        #expect(redacted["Content-Type"] == "application/json")
    }
    
    @Test func bodyTruncationRespectsMaximumBytes() {
        let body = Data("abcdef".utf8)
        let truncated = IrisURLProtocol.truncate(body, maximumBytes: 3)
        
        #expect(truncated == Data("abc".utf8))
        #expect(IrisURLProtocol.truncate(body, maximumBytes: 6) == body)
        #expect(IrisURLProtocol.truncate(nil, maximumBytes: 3) == nil)
    }
    
    @Test func storeDoesNotExceedMaximumTransactions() async throws {
        await resetIris()
        
        for index in 0..<5 {
            await IrisStore.shared.insert(
                transaction(index: index),
                maxStoredTransactions: 3
            )
        }
        
        let transactions = await IrisStore.shared.snapshot()
        #expect(transactions.count == 3)
        #expect(transactions.map(\.method) == ["POST-4", "POST-3", "POST-2"])
    }
    
    @Test func clearRemovesTransactions() async throws {
        await resetIris()
        
        await IrisStore.shared.insert(
            transaction(index: 0),
            maxStoredTransactions: 10
        )
        await IrisStore.shared.clear()
        
        #expect(await IrisStore.shared.snapshot().isEmpty)
    }
    
    @Test func observerContinuesAfterClear() async throws {
        await resetIris()
        
        let stream = await IrisStore.shared.observe()
        var iterator = stream.makeAsyncIterator()
        
        #expect(await iterator.next()?.isEmpty == true)
        
        await IrisStore.shared.insert(
            transaction(index: 0),
            maxStoredTransactions: 10
        )
        #expect(await iterator.next()?.count == 1)
        
        await IrisStore.shared.clear()
        #expect(await iterator.next()?.isEmpty == true)
        
        await IrisStore.shared.insert(
            transaction(index: 1),
            maxStoredTransactions: 10
        )
        #expect(await iterator.next()?.first?.method == "POST-1")
    }
    
    @Test func successfulRequestIsRecorded() async throws {
        await resetIris()
        
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Set-Cookie": "session=abc"]
            )!
            
            return (response, Data("abcdef".utf8))
        }
        
        IrisURLProtocol.setForwardingProtocolClassesForTesting([StubURLProtocol.self])
        Iris.start(
            configuration: IrisConfiguration(maxBodyBytes: 4)
        )
        
        var urlRequest = request("https://example.com/success")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = Data("hello".utf8)
        urlRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: Iris.instrument(.ephemeral))
        let (data, response) = try await session.data(for: urlRequest)
        session.invalidateAndCancel()
        
        #expect(data == Data("abcdef".utf8))
        #expect((response as? HTTPURLResponse)?.statusCode == 201)
        
        let transactions = await eventuallyRecordedTransactions { transactions in
            transactions.first?.state == .completed
        }
        let transaction = try #require(transactions.first)
        
        #expect(transaction.method == "POST")
        #expect(transaction.statusCode == 201)
        #expect(transaction.duration != nil)
        #expect(transaction.requestHeaders["Authorization"] == "Bearer token")
        #expect(transaction.responseHeaders["Set-Cookie"] == "session=abc")
        #expect(transaction.responseBody == Data("abcd".utf8))
    }
    
    @Test func httpBodyStreamIsCapturedAndForwarded() async throws {
        await resetIris()
        
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let requestBody = request.httpBody ?? readStream(request.httpBodyStream)
            
            return (response, requestBody ?? Data())
        }
        
        IrisURLProtocol.setForwardingProtocolClassesForTesting([StubURLProtocol.self])
        Iris.start()
        
        let body = Data(#"{"email":"test@example.com","password":"secret"}"#.utf8)
        let mutableRequest = NSMutableURLRequest(url: URL(string: "https://example.com/stream")!)
        mutableRequest.httpMethod = "POST"
        mutableRequest.httpBodyStream = InputStream(data: body)
        mutableRequest.setValue(
            String(body.count),
            forHTTPHeaderField: "Content-Length"
        )
        mutableRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        
        let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
        let (data, response) = try await session.data(for: mutableRequest as URLRequest)
        session.invalidateAndCancel()
        
        #expect(data == body)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        
        let transactions = await eventuallyRecordedTransactions { transactions in
            transactions.first?.url.absoluteString == "https://example.com/stream"
            && transactions.first?.state == .completed
        }
        let transaction = try #require(transactions.first)
        
        #expect(transaction.requestBody == body)
    }
    
    @Test func autoInjectedSessionRecordsRequestWithoutInstrument() async throws {
        await resetIris()
        
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            
            return (response, Data("auto".utf8))
        }
        
        IrisURLProtocol.setForwardingProtocolClassesForTesting([StubURLProtocol.self])
        Iris.start()
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1
        
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request("https://example.com/auto"))
        session.invalidateAndCancel()
        
        #expect(data == Data("auto".utf8))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        
        let transactions = await eventuallyRecordedTransactions { transactions in
            transactions.first?.url.absoluteString == "https://example.com/auto"
            && transactions.first?.state == .completed
        }
        let transaction = try #require(transactions.first)
        
        #expect(transaction.statusCode == 200)
        #expect(transaction.responseBody == Data("auto".utf8))
    }
    
    @Test func autoInjectionAddsIrisProtocolToDefaultAndEphemeralOnce() async throws {
        await resetIris()
        Iris.start()
        
        let defaultConfiguration = URLSessionConfiguration.default
        let ephemeralConfiguration = URLSessionConfiguration.ephemeral
        
        #expect(countIrisProtocol(in: defaultConfiguration) == 1)
        #expect(countIrisProtocol(in: ephemeralConfiguration) == 1)
        
        Iris.instrument(defaultConfiguration)
        Iris.instrument(ephemeralConfiguration)
        
        #expect(countIrisProtocol(in: defaultConfiguration) == 1)
        #expect(countIrisProtocol(in: ephemeralConfiguration) == 1)
    }
    
    @Test func failedRequestIsRecorded() async throws {
        await resetIris()
        
        StubURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        
        IrisURLProtocol.setForwardingProtocolClassesForTesting([StubURLProtocol.self])
        Iris.start()
        
        let session = URLSession(configuration: Iris.instrument(.ephemeral))
        
        do {
            _ = try await session.data(for: request("https://example.com/failure"))
            Issue.record("Expected request to fail")
        } catch {
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        }
        
        session.invalidateAndCancel()
        
        let transactions = await eventuallyRecordedTransactions { transactions in
            transactions.first?.state == .failed
        }
        let transaction = try #require(transactions.first)
        
        #expect(transaction.state == .failed)
        #expect(transaction.errorDescription != nil)
    }
    
    @Test func concurrentInsertsKeepStoreBounded() async throws {
        await resetIris()
        
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    await IrisStore.shared.insert(
                        transaction(index: index),
                        maxStoredTransactions: 25
                    )
                }
            }
        }
        
        let transactions = await IrisStore.shared.snapshot()
        #expect(transactions.count == 25)
    }
    
    @Test func rowStatusPresentationSeparatesSuccessAndErrors() throws {
        var success = transaction(index: 0)
        success.statusCode = 200
        success.state = .completed
        
        var redirect = transaction(index: 1)
        redirect.statusCode = 302
        redirect.state = .completed
        
        var clientError = transaction(index: 2)
        clientError.statusCode = 400
        clientError.state = .completed
        
        var serverError = transaction(index: 3)
        serverError.statusCode = 500
        serverError.state = .completed
        
        var failed = transaction(index: 4)
        failed.state = .failed
        
        #expect(success.irisStatusText == "200")
        #expect(success.irisStatusKind == .success)
        #expect(redirect.irisStatusKind == .success)
        #expect(clientError.irisStatusText == "400")
        #expect(clientError.irisStatusKind == .error)
        #expect(serverError.irisStatusText == "500")
        #expect(serverError.irisStatusKind == .error)
        #expect(failed.irisStatusText == "ERR")
        #expect(failed.irisStatusKind == .error)
    }
    
    @Test func runningResponseMetadataShowsStatusAndEventStream() throws {
        var eventStream = transaction(index: 0)
        eventStream.statusCode = 200
        eventStream.responseHeaders = ["Content-Type": "text/event-stream"]
        eventStream.state = .running
        
        #expect(eventStream.irisStatusText == "200")
        #expect(eventStream.irisStatusKind == .success)
        #expect(eventStream.irisContentType == "text/event-stream")
    }
    
    @Test func trafficCategoryUsesConfiguredMainHostsAndBaseURLs() async throws {
        await resetIris()
        
        Iris.start(
            configuration: IrisConfiguration(
                mainHosts: ["API.EXAMPLE.com"],
                mainBaseURLs: [URL(string: "https://service.example.com/v1")!]
            )
        )
        
        let mainFromHost = IrisTransaction(
            method: "GET",
            url: URL(string: "https://api.example.com/users")!,
            requestHeaders: [:],
            requestBody: nil
        )
        let mainFromBaseURL = IrisTransaction(
            method: "GET",
            url: URL(string: "https://service.example.com/orders")!,
            requestHeaders: [:],
            requestBody: nil
        )
        let other = IrisTransaction(
            method: "GET",
            url: URL(string: "https://analytics.example.net/log")!,
            requestHeaders: [:],
            requestBody: nil
        )
        
        #expect(mainFromHost.irisTrafficCategory == .main)
        #expect(mainFromBaseURL.irisTrafficCategory == .main)
        #expect(other.irisTrafficCategory == .other)
    }
    
    @Test func gestureCanBeConfiguredGlobally() async throws {
        await resetIris()
        
        #expect(Iris.selectedGesture() == .shake)
        
        Iris.setGesture(.hold(minimumDuration: 1.2))
        #expect(Iris.selectedGesture() == .hold(minimumDuration: 1.2))
        
        Iris.setGesture(.custom)
        #expect(Iris.selectedGesture() == .custom)
        
        Iris.setGesture(.shake)
        #expect(Iris.selectedGesture() == .shake)
    }
}

private func resetIris() async {
    Iris.stop()
    Iris.setGesture(.shake)
    IrisURLProtocol.setForwardingProtocolClassesForTesting([])
    StubURLProtocol.handler = nil
    await IrisStore.shared.clear()
}

private func request(_ urlString: String) -> URLRequest {
    URLRequest(url: URL(string: urlString)!)
}

private func transaction(index: Int) -> IrisTransaction {
    IrisTransaction(
        method: "POST-\(index)",
        url: URL(string: "https://example.com/\(index)")!,
        requestHeaders: [:],
        requestBody: nil
    )
}

private func countIrisProtocol(
    in configuration: URLSessionConfiguration
) -> Int {
    (configuration.protocolClasses ?? []).filter {
        ObjectIdentifier($0) == ObjectIdentifier(IrisURLProtocol.self)
    }.count
}

private func readStream(_ inputStream: InputStream?) -> Data? {
    guard let inputStream else {
        return nil
    }
    
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    
    inputStream.open()
    defer { inputStream.close() }
    
    while inputStream.hasBytesAvailable {
        let byteCount = inputStream.read(
            &buffer,
            maxLength: buffer.count
        )
        
        guard byteCount > 0 else {
            break
        }
        
        data.append(buffer, count: byteCount)
    }
    
    return data
}

private func eventuallyRecordedTransactions(
    matching predicate: ([IrisTransaction]) -> Bool
) async -> [IrisTransaction] {
    for _ in 0..<50 {
        let transactions = await IrisStore.shared.snapshot()
        
        if predicate(transactions) {
            return transactions
        }
        
        try? await Task.sleep(for: .milliseconds(20))
    }
    
    return await IrisStore.shared.snapshot()
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}
