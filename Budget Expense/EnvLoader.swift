// EnvLoader.swift
import Foundation

enum EnvLoader {
    static let shared: [String: String] = {
        guard let filePath = Bundle.main.path(forResource: ".env", ofType: nil),
              let content = try? String(contentsOfFile: filePath, encoding: .utf8)
        else {
            print("⚠️ .env file not found in bundle")
            return [:]
        }
        
        var variables: [String: String] = [:]
        let lines = content.split(whereSeparator: \.isNewline)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            
            // Remove surrounding quotes if present
            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            
            variables[key] = value
        }
        
        return variables
    }()
    
    static func value(for key: String) -> String? {
        shared[key]
    }
}
