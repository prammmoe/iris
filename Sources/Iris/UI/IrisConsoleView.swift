//
//  IrisConsoleView.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

struct IrisConsoleView: View {
    @State private var transactions: [IrisTransaction] = []
    @State private var searchText = ""
    @State private var selectedCategory = IrisTrafficCategory.main
    
    init() {
        let mainHosts = IrisRuntime.shared.snapshot().configuration.mainHosts
        _selectedCategory = State(
            initialValue: mainHosts.isEmpty ? .other : .main
        )
    }
    
    private var categorizedTransactions: [IrisTransaction] {
        transactions.filter {
            $0.irisTrafficCategory == selectedCategory
        }
    }
    
    private var filteredTransactions: [IrisTransaction] {
        guard !searchText.isEmpty else {
            return categorizedTransactions
        }
        
        let keyword = searchText.lowercased()
        
        return categorizedTransactions.filter {
            $0.url.absoluteString.lowercased().contains(keyword)
            || $0.method.lowercased().contains(keyword)
            || String($0.statusCode ?? 0).contains(keyword)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                controlsView
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        summaryRow
                        
                        if filteredTransactions.isEmpty {
                            emptyView
                        } else {
                            ForEach(filteredTransactions) { transaction in
                                NavigationLink {
                                    IrisTransactionDetailView(transaction: transaction)
                                } label: {
                                    IrisTransactionRowView(transaction: transaction)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .background(IrisConsoleColor.groupedBackground)
            }
            .navigationTitle("Requests")
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Iris.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                #endif
                
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarTrailing) {
                    clearButton
                }
                #else
                ToolbarItem {
                    clearButton
                }
                #endif
            }
        }
        .task {
            let stream = await IrisStore.shared.observe()
            
            for await newTransactions in stream {
                transactions = newTransactions
            }
        }
    }
    
    private var clearButton: some View {
        Button {
            Iris.clear()
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel("Clear")
    }
    
    private var controlsView: some View {
        VStack(spacing: 10) {
            searchField
            
            Picker(
                "Category",
                selection: $selectedCategory
            ) {
                ForEach(IrisTrafficCategory.allCases) { category in
                    Text(category.title)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(IrisConsoleColor.background)
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search URL, method, or status", text: $searchText)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.body)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(IrisConsoleColor.searchBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var summaryRow: some View {
        HStack(spacing: 18) {
            summaryItem(
                title: "All",
                count: categorizedTransactions.count
            )
            
            summaryItem(
                title: "Success",
                count: categorizedTransactions.filter { $0.irisStatusKind == .success }.count
            )
            
            summaryItem(
                title: "Error",
                count: categorizedTransactions.filter { $0.irisStatusKind == .error }.count
            )
            
            summaryItem(
                title: "Running",
                count: categorizedTransactions.filter { $0.irisStatusKind == .running }.count
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(IrisConsoleColor.background)
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
    
    private var emptyView: some View {
        Text("No requests")
            .font(.callout)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(IrisConsoleColor.background)
    }
}

struct IrisTransactionRowView: View {
    let transaction: IrisTransaction
    
    var body: some View {
        HStack(spacing: 0) {
            statusColumn
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 18) {
                    Text(transaction.method)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(transaction.irisContentType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    if let byteCount = transaction.responseBody?.count {
                        Text("\(byteCount) B")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if transaction.state == .failed,
                   let error = transaction.errorDescription {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 64)
        .background(IrisConsoleColor.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(IrisConsoleColor.separator)
                .frame(height: 1)
        }
    }
    
    private var statusColumn: some View {
        VStack(spacing: 4) {
            Text(transaction.irisListTimeText)
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(transaction.irisListDurationText)
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(1)
            
            Text(transaction.irisStatusText)
                .font(.caption2.bold().monospacedDigit())
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
        .frame(width: 68)
        .frame(maxHeight: .infinity)
        .background(transaction.irisStatusColor)
    }
}

enum IrisTransactionStatusKind: Equatable {
    case running
    case success
    case error
}

enum IrisConsoleColor {
    static var background: Color {
        #if canImport(UIKit)
        return Color(.systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
    
    static var groupedBackground: Color {
        #if canImport(UIKit)
        return Color(.systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.08)
        #endif
    }
    
    static var searchBackground: Color {
        #if canImport(UIKit)
        return Color(.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
    
    static var detailBackground: Color {
        #if canImport(UIKit)
        return Color(.systemGray6)
        #elseif canImport(AppKit)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color.gray.opacity(0.06)
        #endif
    }
    
    static var detailSegmentBackground: Color {
        #if canImport(UIKit)
        return Color(.systemGray3)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    static var disclosure: Color {
        #if canImport(UIKit)
        return Color(.tertiaryLabel)
        #elseif canImport(AppKit)
        return Color(nsColor: .tertiaryLabelColor)
        #else
        return Color.gray
        #endif
    }
    
    static var separator: Color {
        #if canImport(UIKit)
        return Color(.separator)
        #elseif canImport(AppKit)
        return Color(nsColor: .separatorColor)
        #else
        return Color.gray.opacity(0.35)
        #endif
    }
}

enum IrisTrafficCategory: String, CaseIterable, Identifiable {
    case main
    case other
    
    var id: String {
        rawValue
    }
    
    var title: String {
        switch self {
        case .main:
            return "Main"
        case .other:
            return "Other"
        }
    }
}

extension IrisTransaction {
    var irisTrafficCategory: IrisTrafficCategory {
        let mainHosts = IrisRuntime.shared.snapshot().configuration.mainHosts
        
        guard let host = url.host?.lowercased(),
              mainHosts.contains(host) else {
            return .other
        }
        
        return .main
    }
    
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
    
    var irisListTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return formatter.string(from: startedAt)
    }
    
    var irisListDurationText: String {
        guard let duration else {
            return "-"
        }
        
        return String(format: "%.2f", duration)
    }
    
    var irisContentType: String {
        requestHeaders.firstHeaderValue(named: "Content-Type")
        ?? responseHeaders.firstHeaderValue(named: "Content-Type")
        ?? "-"
    }
}

extension Dictionary where Key == String, Value == String {
    func firstHeaderValue(named name: String) -> String? {
        first { key, _ in
            key.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}
