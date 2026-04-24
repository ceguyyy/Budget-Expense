// VertexAIService.swift
import Foundation

enum VertexAIError: Error, LocalizedError {
    case invalidResponse
    case noAccessToken
    case imageProcessingFailed
    case missingConfiguration(String)
    case apiError(Int, String)
    case noValidResponse
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .noAccessToken:
            return "No access token available"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .missingConfiguration(let key):
            return "Missing configuration: \(key). Please add \(key) to your .env file."
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        case .noValidResponse:
            return "AI service returned no valid response"
        case .uploadFailed(let message):
            return "Failed to upload image: \(message)"
        }
    }
}

enum VertexAIService {
    static func scanReceipt(imageData: Data) async throws -> String {
        guard let apiKey = EnvLoader.value(for: "VERTEX_API_KEY"),
              let modelID = EnvLoader.value(for: "VERTEX_MODEL_ID")
        else {
            throw VertexAIError.missingConfiguration(
                EnvLoader.value(for: "VERTEX_API_KEY") == nil ? "VERTEX_API_KEY" : "VERTEX_MODEL_ID"
            )
        }
        
        // Step 1: Upload the image using the File API
        let fileURI = try await uploadImage(imageData: imageData, apiKey: apiKey)
        
        // Step 2: Use the file URI in generateContent
        let prompt = """
        Extract all expense details from this receipt image. 
        Return ONLY a valid JSON object with NO markdown formatting, NO code blocks, just raw JSON with these fields:
        - merchant: String
        - date: String (YYYY-MM-DD)
        - total_amount: Double
        - items: array of {name: String, price: Double}
        - currency: String (default "USD")
        """
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent"
        
        let requestBody: [String: Any] = [
            "contents": [[
                "parts": [
                    ["file_data": [
                        "mime_type": "image/jpeg",
                        "file_uri": fileURI
                    ]],
                    ["text": prompt]
                ]
            ]],
            "generation_config": [
                "temperature": 0.2,
                "maxOutputTokens": 4096,
                "topP": 0.95
            ]
        ]
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VertexAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("❌ API Error Response: \(responseStr)")
                }
                throw VertexAIError.apiError(httpResponse.statusCode, message)
            }
            if let responseStr = String(data: data, encoding: .utf8) {
                print("❌ API Error Response: \(responseStr)")
            }
            throw VertexAIError.apiError(httpResponse.statusCode, "Unknown error")
        }
        
        return try parseResponse(data)
    }
    
    static func getFinancialRecommendation(prompt: String) async throws -> String {
        guard let apiKey = EnvLoader.value(for: "VERTEX_API_KEY") else {
            throw VertexAIError.missingConfiguration("VERTEX_API_KEY")
        }

        // Use the Gemini model ID from env or fallback to lite
        let modelID = EnvLoader.value(for: "VERTEX_MODEL_ID") ?? "gemini-2.5-flash"
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent?key=\(apiKey)"

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1000,
                "topP": 0.95
            ]
        ]

        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VertexAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Gemini API Error (\(httpResponse.statusCode)):", errorText)
            throw VertexAIError.apiError(httpResponse.statusCode, errorText)
        }

        return try parseGeminiResponse(data)
    }
    
    static func parseGeminiResponse(_ data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard
            let candidates = json?["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw VertexAIError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - File API Upload
    
    private static func uploadImage(imageData: Data, apiKey: String) async throws -> String {
        let mimeType = "image/jpeg"
        let numBytes = imageData.count
        let displayName = "receipt_\(Date().timeIntervalSince1970)"
        
        // Step 1: Start resumable upload - get upload URL
        guard let uploadURL = try await startResumableUpload(
            apiKey: apiKey,
            mimeType: mimeType,
            numBytes: numBytes,
            displayName: displayName
        ) else {
            throw VertexAIError.uploadFailed("Failed to get upload URL")
        }
        
        print("📤 Uploading image to: \(uploadURL)")
        
        // Step 2: Upload the actual bytes
        let fileURI = try await uploadBytes(
            uploadURL: uploadURL,
            imageData: imageData,
            apiKey: apiKey,
            numBytes: numBytes
        )
        
        print("✅ Image uploaded successfully. File URI: \(fileURI)")
        return fileURI
    }
    
    private static func startResumableUpload(
        apiKey: String,
        mimeType: String,
        numBytes: Int,
        displayName: String
    ) async throws -> String? {
        let urlString = "https://generativelanguage.googleapis.com/upload/v1beta/files"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue("\(numBytes)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        request.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata: [String: Any] = [
            "file": [
                "display_name": displayName
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              let uploadURL = httpResponse.allHeaderFields["X-Goog-Upload-URL"] as? String ?? 
                             httpResponse.allHeaderFields["x-goog-upload-url"] as? String else {
            return nil
        }
        
        return uploadURL
    }
    
    private static func uploadBytes(
        uploadURL: String,
        imageData: Data,
        apiKey: String,
        numBytes: Int
    ) async throws -> String {
        guard let url = URL(string: uploadURL) else {
            throw VertexAIError.uploadFailed("Invalid upload URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("\(numBytes)", forHTTPHeaderField: "Content-Length")
        request.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.httpBody = imageData
        request.timeoutInterval = 120 // Longer timeout for upload
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Upload failed: \(statusCode) - \(responseStr)")
            throw VertexAIError.uploadFailed("Upload failed with status \(statusCode)")
        }
        
        // Parse the response to get the file URI
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let file = json["file"] as? [String: Any],
              let fileURI = file["uri"] as? String else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown response"
            print("⚠️ Failed to parse upload response: \(responseStr)")
            throw VertexAIError.uploadFailed("Failed to parse upload response")
        }
        
        return fileURI
    }
    
    // MARK: - Response Parsing
    
    private static func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("⚠️ Raw response: \(responseStr.prefix(500))")
            }
            throw VertexAIError.invalidResponse
        }
        
        // Handle Gemini API response format
        if let candidates = json["candidates"] as? [[String: Any]],
           let first = candidates.first,
           let content = first["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            // Clean up markdown code blocks if present
            let cleaned = text
                .replacingOccurrences(of: "```json\n", with: "")
                .replacingOccurrences(of: "```\n", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned
        }
        
        // Try to extract from error
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw VertexAIError.apiError(0, message)
        }
        
        if let responseStr = String(data: data, encoding: .utf8) {
            print("⚠️ Raw response: \(responseStr.prefix(500))")
        }
        throw VertexAIError.noValidResponse
    }
}
