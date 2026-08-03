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
        maxBodyBytes: Int = 2_000_000, // Max 2 MB per body
        ignoredHosts: Set<String> = [],
        redactedHeaders: Set<String> = []
    ) {
        self.maxStoredTransactions = maxStoredTransactions
        self.maxBodyBytes = maxBodyBytes
        self.ignoredHosts = ignoredHosts
        self.redactedHeaders = Set(
            redactedHeaders.map { $0.lowercased() }
        )
    }
}
