//
//  IrisConsoleView.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import SwiftUI

struct IrisConsoleView: View {
    @State private var transactions: [IrisTransaction] = []
    @State private var searchText = ""
    
    private var filteredTransactions: [IrisTransaction] {
        guard !searchText.isEmpty else {
            return transactions
        }
        
        let keyword = searchText.lowercased()
        
        return transactions.filter {
            $0.url.absoluteString.lowercased().contains(keyword)
            || $0.method.lowercased().contains(keyword)
            || String($0.statusCode ?? 0).contains(keyword)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    summaryRow
                }
                
                Section {
                    ForEach(filteredTransactions) { transaction in
                        NavigationLink {
                            IrisTransactionDetailView(transaction: transaction)
                        } label: {
                            IrisTransactionRowView(transaction: transaction)
                        }
                    }
                }
            }
            .navigationTitle("Iris")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem {
                    Button("Clear") {
                        Iris.clear()
                    }
                }
            }
        }
        .task {
            let stream = await IrisStore.shared.observe()
            
            for await newTransactions in stream {
                transactions = newTransactions
            }
        }
    }
    
    private var summaryRow: some View {
        HStack(spacing: 18) {
            summaryItem(
                title: "All",
                count: transactions.count
            )
            
            summaryItem(
                title: "Success",
                count: transactions.filter { $0.irisStatusKind == .success }.count
            )
            
            summaryItem(
                title: "Error",
                count: transactions.filter { $0.irisStatusKind == .error }.count
            )
            
            summaryItem(
                title: "Running",
                count: transactions.filter { $0.irisStatusKind == .running }.count
            )
        }
        .padding(.vertical, 4)
    }
    
    private func summaryItem(title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(String(count))
                .font(.headline.monospacedDigit())
        }
    }
}

struct IrisTransactionRowView: View {
    let transaction: IrisTransaction
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusBadge
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(transaction.method)
                        .font(.caption.bold())
                        .lineLimit(1)
                    
                    Text(transaction.url.host ?? "-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    Text(transaction.irisTimestampText)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(pathText)
                    .font(.caption)
                    .lineLimit(2)
                
                HStack(spacing: 10) {
                    if let duration = transaction.duration {
                        Text(String(format: "%.0f ms", duration * 1_000))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    if let byteCount = transaction.responseBody?.count {
                        Text("\(byteCount) B")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private var statusBadge: some View {
        Text(transaction.irisStatusText)
            .font(.caption.bold().monospacedDigit())
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 56, height: 42)
            .background(transaction.irisStatusColor)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private var pathText: String {
        var components = URLComponents(
            url: transaction.url,
            resolvingAgainstBaseURL: false
        )
        components?.scheme = nil
        components?.host = nil
        components?.port = nil
        
        let path = components?.string
        
        if let path,
           !path.isEmpty {
            return path
        }
        
        return transaction.url.absoluteString
    }
}

enum IrisTransactionStatusKind: Equatable {
    case running
    case success
    case error
}

extension IrisTransaction {
    var irisStatusText: String {
        switch state {
        case .running:
            return "..."
        case .completed:
            return statusCode.map(String.init) ?? "-"
        case .failed:
            return statusCode.map(String.init) ?? "ERR"
        }
    }
    
    var irisStatusKind: IrisTransactionStatusKind {
        switch state {
        case .running:
            return .running
        case .failed:
            return .error
        case .completed:
            guard let statusCode else {
                return .error
            }
            
            return (200..<400).contains(statusCode) ? .success : .error
        }
    }
    
    var irisStatusColor: Color {
        switch irisStatusKind {
        case .running:
            return Color.orange
        case .success:
            return Color.green
        case .error:
            return Color.red
        }
    }
    
    var irisTimestampText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        return formatter.string(from: startedAt)
    }
}
