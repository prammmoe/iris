//
//  IrisConfiguration.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

public struct IrisConfiguration: Sendable {
    public var maxStoredTransactions: Int
    public var maxBodyBytes: Int
    public var ignoredHosts: Set<String>
    public var redactedHeaders: Set<String>
    
    public init(
        maxStoredTransactions: Int = 500,
        maxBodyBytes: Int = 1_000_000,
        ignoredHosts: Set<String> = [],
        redactedHeaders: Set<String> = [
            "authorization",
            "proxy-authorization",
            "cookie",
            "set-cookie",
            "x-api-key",
            "x-signature"
        ]
    ) {
        self.maxStoredTransactions = maxStoredTransactions
        self.maxBodyBytes = maxBodyBytes
        self.ignoredHosts = Set(ignoredHosts.map { $0.lowercased() })
        self.redactedHeaders = Set(
            redactedHeaders.map { $0.lowercased() }
        )
    }
}
