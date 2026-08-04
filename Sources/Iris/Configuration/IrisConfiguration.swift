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
    public var mainHosts: Set<String>
    public var redactedHeaders: Set<String>
    
    public init(
        maxStoredTransactions: Int = 500,
        maxBodyBytes: Int = 1_000_000,
        ignoredHosts: Set<String> = [],
        mainHosts: Set<String> = [],
        mainBaseURLs: Set<URL> = [],
        redactedHeaders: Set<String> = []
    ) {
        self.maxStoredTransactions = maxStoredTransactions
        self.maxBodyBytes = maxBodyBytes
        self.ignoredHosts = Set(ignoredHosts.map { $0.lowercased() })
        self.mainHosts = Self.normalizedHosts(
            hosts: mainHosts,
            baseURLs: mainBaseURLs
        )
        self.redactedHeaders = Set(
            redactedHeaders.map { $0.lowercased() }
        )
    }
    
    private static func normalizedHosts(
        hosts: Set<String>,
        baseURLs: Set<URL>
    ) -> Set<String> {
        var normalizedHosts = Set(hosts.map { $0.lowercased() })
        
        for baseURL in baseURLs {
            if let host = baseURL.host?.lowercased() {
                normalizedHosts.insert(host)
            }
        }
        
        return normalizedHosts
    }
}
