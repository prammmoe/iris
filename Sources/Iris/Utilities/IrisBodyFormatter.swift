//
//  IrisBodyFormatter.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

enum IrisBodyFormatter {
    static func string(from data: Data?) -> String {
        guard let data else {
            return "No body"
        }
        
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let formattedData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
           ),
           let formattedString = String(data: formattedData, encoding: .utf8) {
            return formattedString
        }
        
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        
        return "<binary data: \(data.count) bytes>"
    }
}
