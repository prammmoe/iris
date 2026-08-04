//
//  IrisTransactionDetailView.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import SwiftUI

struct IrisTransactionDetailView: View {
    let transaction: IrisTransaction
    
    @State private var selectedSection = IrisTransactionDetailSection.info
    
    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
            
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    selectedContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
            .background(IrisConsoleColor.detailBackground)
        }
        .navigationTitle("Details")
    }
    
    private var sectionPicker: some View {
        Picker(
            "Details",
            selection: $selectedSection
        ) {
            ForEach(IrisTransactionDetailSection.allCases) { section in
                Text(section.title)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(IrisConsoleColor.detailSegmentBackground)
    }
    
    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .info:
            infoContent
        case .request:
            requestContent
        case .response:
            responseContent
        }
    }
    
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            plainField(title: "URL", value: transaction.url.absoluteString)
            plainField(title: "Method", value: transaction.method)
            plainField(title: "Status", value: transaction.statusCode.map(String.init) ?? "-")
            plainField(title: "Request date", value: transaction.startedAt.irisDetailDateText)
            plainField(title: "Response date", value: transaction.endedAt?.irisDetailDateText ?? "-")
            plainField(title: "Time interval", value: transaction.duration.map { String(format: "%.8f", $0) } ?? "-")
            plainField(title: "Response size", value: transaction.responseBody.map { "\($0.count) B" } ?? "-")
            plainField(title: "Content type", value: transaction.irisContentType)
            
            if let error = transaction.errorDescription {
                plainField(title: "Error", value: error)
            }
        }
    }
    
    private var requestContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            groupedText(title: "Headers") {
                headersContent(transaction.requestHeaders)
            }
            
            groupedText(title: "Body") {
                bodyContent(transaction.requestBody)
            }
        }
    }
    
    private var responseContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            groupedText(title: "Headers") {
                headersContent(transaction.responseHeaders)
            }
            
            groupedText(title: "Body") {
                bodyContent(transaction.responseBody)
            }
        }
    }
    
    private func plainField(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("[\(title)]")
                .font(.body)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func groupedText<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("-- \(title) --")
                .font(.headline)
                .foregroundColor(.orange)
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func headersContent(
        _ headers: [String: String]
    ) -> some View {
        if headers.isEmpty {
            Text("-")
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    plainField(
                        title: key,
                        value: headers[key] ?? ""
                    )
                }
            }
        }
    }
    
    private func bodyContent(
        _ data: Data?
    ) -> some View {
        Text(IrisBodyFormatter.string(from: data))
            .font(.body.monospaced())
            .foregroundColor(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum IrisTransactionDetailSection: String, CaseIterable, Identifiable {
    case info
    case request
    case response
    
    var id: String {
        rawValue
    }
    
    var title: String {
        switch self {
        case .info:
            return "Info"
        case .request:
            return "Request"
        case .response:
            return "Response"
        }
    }
}

private extension Date {
    var irisDetailDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        return formatter.string(from: self)
    }
}
