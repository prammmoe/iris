//
//  IrisRuntime.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

struct IrisRuntimeSnapshot: Sendable {
    let isEnabled: Bool
    let configuration: IrisConfiguration
}

final class IrisRuntime: @unchecked Sendable {
    static let shared = IrisRuntime()
    
    private let lock = NSLock()
    
    private var isEnabled = false
    private var configuration = IrisConfiguration()
    
    private init() {}
    
    func start(configuration: IrisConfiguration) {
        lock.lock()
        self.configuration = configuration
        isEnabled = true
        lock.unlock()
    }
    
    func stop() {
        lock.lock()
        isEnabled = false
        lock.unlock()
    }
    
    func snapshot() -> IrisRuntimeSnapshot {
        lock.lock()
        defer { lock.unlock() }
        
        return IrisRuntimeSnapshot(
            isEnabled: isEnabled,
            configuration: configuration
        )
    }
}
