//
//  IrisRedactor.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation

enum IrisRedactor {
    static func headers(
        _ headers: [String: String],
        redactedNames: Set<String>
    ) -> [String: String] {
        headers.reduce(into: [:]) { result, item in
            let name = item.key
            let value = item.value
            
            if redactedNames.contains(name.lowercased()) {
                result[name] = "<redacted>"
            } else {
                // Display
                result[name] = value
            }
        }
    }
}
