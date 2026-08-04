//
//  IrisTransactionDetailView.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import SwiftUI

struct IrisTransactionDetailView: View {
    let transaction: IrisTransaction
    
    var body: some View {
        List {
            Section("General") {
                detailRow(title: "Method", value: transaction.method)
                detailRow(title: "URL", value: transaction.url.absoluteString)
                detailRow(title: "Status", value: transaction.statusCode.map(String.init) ?? "-")
                
                if let duration = transaction.duration {
                    detailRow(
                        title: "Duration",
                        value: String(format: "%.0f ms", duration * 1_000)
                    )
                }
            }
            
            Section("Request Headers") {
                headersView(transaction.requestHeaders)
            }
            
            Section("Request Body") {
                bodyText(transaction.requestBody)
            }
            
            Section("Response Headers") {
                headersView(transaction.responseHeaders)
            }
            
            Section("Response Body") {
                bodyText(transaction.responseBody)
            }
            
            if let error = transaction.errorDescription {
                Section("Error") {
                    Text(error)
                }
            }
        }
        .navigationTitle(transaction.method)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .textSelection(.enabled)
        }
    }
    
    private func headersView(_ headers: [String: String]) -> some View {
        ForEach(headers.keys.sorted(), id: \.self) { key in
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.caption.bold())
                
                Text(headers[key] ?? "")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
    }
    
    private func bodyText(_ data: Data?) -> some View {
        Text(IrisBodyFormatter.string(from: data))
            .font(.caption.monospaced())
            .textSelection(.enabled)
    }
}
