//
//  IrisTransactionDetailView.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct IrisTransactionDetailView: View {
    let transaction: IrisTransaction
    
    @State private var selectedSection = IrisTransactionDetailSection.info
    @State private var exportFile: IrisExportFile?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                selectedContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(IrisConsoleColor.detailBackground)
        .safeAreaInset(edge: .top, spacing: 0) {
            sectionPicker
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                shareMenu
            }
        }
        .sheet(item: $exportFile) { file in
            #if canImport(UIKit)
            IrisActivityView(activityItems: [file.url])
            #else
            Text(file.url.path)
                .padding()
            #endif
        }
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
        .frame(maxWidth: .infinity)
        .background(IrisConsoleColor.detailSegmentBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(IrisConsoleColor.separator)
                .frame(height: 1)
        }
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
        detailSection(title: "Info") {
            fieldsContent(transaction.irisInfoFields)
        }
    }
    
    private var requestContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            detailSection(title: "Request Headers") {
                headersContent(transaction.requestHeaders)
            }
            
            detailSection(title: "Request Body") {
                bodyContent(transaction.requestBody)
            }
        }
    }
    
    private var responseContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            detailSection(title: "Response Headers") {
                headersContent(transaction.responseHeaders)
            }
            
            detailSection(title: "Response Body") {
                bodyContent(transaction.responseBody)
            }
        }
    }
    
    private var shareMenu: some View {
        Menu {
            Button {
                IrisClipboard.copy(transaction.irisCurlText)
            } label: {
                Label("Copy cURL", systemImage: "doc.on.doc")
            }
            
            Button {
                exportFile = IrisExportFile.make(
                    contents: transaction.irisExportText,
                    transactionID: transaction.id
                )
            } label: {
                Label("Export as .txt", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share")
    }
    
    private func plainField(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("[\(title)]")
                .font(.callout)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.callout)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func detailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(IrisConsoleColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            fieldsContent(
                headers.keys.sorted().map {
                    IrisDetailField(title: $0, value: headers[$0] ?? "")
                }
            )
        }
    }
    
    private func fieldsContent(
        _ fields: [IrisDetailField]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(fields.indices, id: \.self) { index in
                plainField(
                    title: fields[index].title,
                    value: fields[index].value
                )
                
                if index < fields.index(before: fields.endIndex) {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
    }
    
    private func bodyContent(
        _ data: Data?
    ) -> some View {
        Text(IrisBodyFormatter.string(from: data))
            .font(.callout.monospaced())
            .foregroundColor(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IrisDetailField {
    let title: String
    let value: String
}

private struct IrisExportFile: Identifiable {
    let id = UUID()
    let url: URL
    
    static func make(
        contents: String,
        transactionID: UUID
    ) -> IrisExportFile? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("iris-\(transactionID.uuidString)")
            .appendingPathExtension("txt")
        
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return IrisExportFile(url: url)
        } catch {
            return nil
        }
    }
}

#if canImport(UIKit)
private struct IrisActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }
    
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
#endif

enum IrisClipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

extension IrisTransaction {
    var irisCurlText: String {
        var components = [
            "curl",
            "-X \(method.shellQuotedForIris)",
            url.absoluteString.shellQuotedForIris
        ]
        
        for key in requestHeaders.keys.sorted() {
            components.append(
                "-H \("\(key): \(requestHeaders[key] ?? "")".shellQuotedForIris)"
            )
        }
        
        if let requestBody {
            components.append(
                "--data-binary \(IrisBodyFormatter.string(from: requestBody).shellQuotedForIris)"
            )
        }
        
        return components.joined(separator: " \\\n  ")
    }
}

private extension IrisTransaction {
    var irisInfoFields: [IrisDetailField] {
        var fields = [
            IrisDetailField(title: "URL", value: url.absoluteString),
            IrisDetailField(title: "Method", value: method),
            IrisDetailField(title: "Status", value: statusCode.map(String.init) ?? "-"),
            IrisDetailField(title: "Request date", value: startedAt.irisDetailDateText),
            IrisDetailField(title: "Response date", value: endedAt?.irisDetailDateText ?? "-"),
            IrisDetailField(title: "Time interval", value: duration.map { String(format: "%.8f", $0) } ?? "-"),
            IrisDetailField(title: "Response size", value: responseBody.map { "\($0.count) B" } ?? "-"),
            IrisDetailField(title: "Content type", value: irisContentType)
        ]
        
        if let errorDescription {
            fields.append(
                IrisDetailField(title: "Error", value: errorDescription)
            )
        }
        
        return fields
    }
    
    var irisExportText: String {
        [
            "INFO",
            irisFieldsText(irisInfoFields),
            "",
            "REQUEST",
            "Headers",
            irisHeadersText(requestHeaders),
            "",
            "Body",
            IrisBodyFormatter.string(from: requestBody),
            "",
            "RESPONSE",
            "Headers",
            irisHeadersText(responseHeaders),
            "",
            "Body",
            IrisBodyFormatter.string(from: responseBody)
        ].joined(separator: "\n")
    }
    
    private func irisFieldsText(_ fields: [IrisDetailField]) -> String {
        fields.map {
            "\($0.title): \($0.value)"
        }
        .joined(separator: "\n")
    }
    
    private func irisHeadersText(_ headers: [String: String]) -> String {
        guard !headers.isEmpty else {
            return "-"
        }
        
        return headers.keys.sorted()
            .map { "\($0): \(headers[$0] ?? "")" }
            .joined(separator: "\n")
    }
}

private extension String {
    var shellQuotedForIris: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
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
