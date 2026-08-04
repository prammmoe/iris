//
//  IrisURLProtocol.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

final class IrisURLProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "com.iris.request-handled"
    private static let forwardingLock = NSLock()
    nonisolated(unsafe) private static var forwardingProtocolClassesForTesting: [AnyClass] = []
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var insertTask: Task<Void, Never>?
    
    override class func canInit(with request: URLRequest) -> Bool {
        canServe(request)
    }
    
    override class func canInit(with task: URLSessionTask) -> Bool {
        if #available(iOS 13.0, macOS 10.15, *),
           task is URLSessionWebSocketTask {
            return false
        }
        
        guard let request = task.currentRequest else {
            return false
        }
        
        return canServe(request)
    }
    
    private class func canServe(_ request: URLRequest) -> Bool {
        let runtime = IrisRuntime.shared.snapshot()
        
        guard runtime.isEnabled else {
            return false
        }
        
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else {
            return false
        }
        
        guard
            let url = request.url,
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return false
        }
        
        if let host = url.host?.lowercased(),
           runtime.configuration.ignoredHosts.contains(host) {
            return false
        }
        
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    static func setForwardingProtocolClassesForTesting(_ protocolClasses: [AnyClass]) {
        forwardingLock.lock()
        forwardingProtocolClassesForTesting = protocolClasses
        forwardingLock.unlock()
    }
    
    private static func forwardingProtocolClasses() -> [AnyClass] {
        forwardingLock.lock()
        defer { forwardingLock.unlock() }
        
        return forwardingProtocolClassesForTesting
    }
    
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        
        let outgoingRequest = mutableRequest as URLRequest
        let runtime = IrisRuntime.shared.snapshot()
        let configuration = runtime.configuration
        let transactionID = UUID()
        
        let requestHeaders = IrisRedactor.headers(
            outgoingRequest.allHTTPHeaderFields ?? [:],
            redactedNames: configuration.redactedHeaders
        )
        
        let requestBody = Self.truncate(
            outgoingRequest.httpBody,
            maximumBytes: configuration.maxBodyBytes
        )
        
        let transaction = IrisTransaction(
            id: transactionID,
            method: outgoingRequest.httpMethod ?? "GET",
            url: url,
            requestHeaders: requestHeaders,
            requestBody: requestBody
        )
        
        insertTask = Task {
            await IrisStore.shared.insert(
                transaction,
                maxStoredTransactions: configuration.maxStoredTransactions
            )
        }
        
        let forwardingConfiguration = URLSessionConfiguration.ephemeral
        forwardingConfiguration.protocolClasses = Self.forwardingProtocolClasses()
        
        let forwardingSession = URLSession(configuration: forwardingConfiguration)
        session = forwardingSession
        
        dataTask = forwardingSession.dataTask(with: outgoingRequest) { [weak self] data, response, error in
            guard let self else {
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let rawResponseHeaders: [String: String]
            
            if let httpResponse = response as? HTTPURLResponse {
                rawResponseHeaders = httpResponse.allHeaderFields.reduce(into: [:]) { result, item in
                    result[String(describing: item.key)] = String(describing: item.value)
                }
            } else {
                rawResponseHeaders = [:]
            }
            
            let responseHeaders = IrisRedactor.headers(
                rawResponseHeaders,
                redactedNames: configuration.redactedHeaders
            )
            
            let responseBody = Self.truncate(data, maximumBytes: configuration.maxBodyBytes)
            let insertion = self.insertTask
            
            Task {
                await insertion?.value
                
                await IrisStore.shared.complete(
                    id: transactionID,
                    statusCode: statusCode,
                    responseHeaders: responseHeaders,
                    responseBody: responseBody,
                    errorDescription: error?.localizedDescription
                )
            }
            
            if let response {
                self.client?.urlProtocol(
                    self,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
            }
            
            if let data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
            
            forwardingSession.finishTasksAndInvalidate()
        }
        
        dataTask?.resume()
    }
    
    override func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        
        dataTask = nil
        session = nil
    }
    
    static func truncate(_ data: Data?, maximumBytes: Int) -> Data? {
        guard let data else {
            return nil
        }
        
        guard data.count > maximumBytes else {
            return data
        }
        
        return Data(data.prefix(maximumBytes))
    }
}
