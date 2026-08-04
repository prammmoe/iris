//
//  IrisStore.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

actor IrisStore {
    static let shared = IrisStore()
    
    private var transactions: [IrisTransaction] = []
    private var observers: [UUID: AsyncStream<[IrisTransaction]>.Continuation] = [:]
    
    private init() {}
    
    func observe() -> AsyncStream<[IrisTransaction]> {
        let observerID = UUID()
        let pair = AsyncStream<[IrisTransaction]>.makeStream()
        
        observers[observerID] = pair.continuation
        pair.continuation.yield(transactions)
        
        pair.continuation.onTermination = { @Sendable _ in
            Task {
                await IrisStore.shared.removeObserver(observerID)
            }
        }
        
        return pair.stream
    }
    
    func insert(
        _ transaction: IrisTransaction,
        maxStoredTransactions: Int
    ) {
        transactions.insert(transaction, at: 0)
        
        if transactions.count > maxStoredTransactions {
            transactions.removeLast(transactions.count - maxStoredTransactions)
        }
        
        broadcast()
    }
    
    func complete(
        id: UUID,
        statusCode: Int?,
        responseHeaders: [String: String],
        responseBody: Data?,
        errorDescription: String?
    ) {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        transactions[index].endedAt = Date()
        transactions[index].statusCode = statusCode
        transactions[index].responseHeaders = responseHeaders
        transactions[index].responseBody = responseBody
        transactions[index].errorDescription = errorDescription
        transactions[index].state = errorDescription == nil ? .completed : .failed
        
        broadcast()
    }
    
    func updateResponse(
        id: UUID,
        statusCode: Int?,
        responseHeaders: [String: String],
        responseBody: Data?
    ) {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        transactions[index].statusCode = statusCode
        transactions[index].responseHeaders = responseHeaders
        transactions[index].responseBody = responseBody
        
        broadcast()
    }
    
    func clear() {
        transactions.removeAll()
        broadcast()
    }
    
    func snapshot() -> [IrisTransaction] {
        transactions
    }
    
    private func broadcast() {
        for observer in observers.values {
            observer.yield(transactions)
        }
    }
    
    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
