//
//  IrisTransaction.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

public struct IrisTransaction: Identifiable, Sendable, Equatable {
    public enum State: String, Sendable {
        case running
        case completed
        case failed
    }
    
    public let id: UUID
    public let startedAt: Date
    
    public var endedAt: Date?
    
    public let method: String
    public let url: URL
    
    public let requestHeaders: [String: String]
    public let requestBody: Data?
    
    public var statusCode: Int?
    public var responseHeaders: [String: String]
    public var responseBody: Data?
    
    public var errorDescription: String?
    public var state: State
    
    public var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
    
    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        method: String,
        url: URL,
        requestHeaders: [String: String],
        requestBody: Data?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.method = method
        self.url = url
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        
        endedAt = nil
        statusCode = nil
        responseHeaders = [:]
        responseBody = nil
        errorDescription = nil
        state = .running
    }
}
