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
            .navigationTitle("")
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
            
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundColor(IrisConsoleColor.disclosure)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(IrisConsoleColor.background)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 84)
        }
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
    
    static var disclosure: Color {
        #if canImport(UIKit)
        return Color(.tertiaryLabel)
        #elseif canImport(AppKit)
        return Color(nsColor: .tertiaryLabelColor)
        #else
        return Color.gray
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
}
