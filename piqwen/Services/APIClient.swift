//
//  APIClient.swift
//  PiQwen
//
//  Network layer for communicating with the Raspberry Pi AI server
//

import Foundation
import Combine

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Health Check
    
    func checkHealth(settings: AppSettings) async throws -> HealthResponse {
        guard let url = URL(string: settings.healthURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(HealthResponse.self, from: data)
    }
    
    func testConnection(settings: AppSettings) async throws -> TestResponse {
        guard let url = URL(string: settings.testURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(TestResponse.self, from: data)
    }
    
    // MARK: - Chat
    
    struct ChatRequest: Encodable {
        let message: String
        let systemPrompt: String?
        let maxTokens: Int?
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let stream: Bool
        
        enum CodingKeys: String, CodingKey {
            case message
            case systemPrompt = "system_prompt"
            case maxTokens = "max_tokens"
            case temperature
            case topP = "top_p"
            case topK = "top_k"
            case stream
        }
    }
    
    func sendChat(
        message: String,
        settings: AppSettings,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil
    ) async throws -> ServerResponse {
        guard let url = URL(string: settings.chatURL) else {
            throw APIError.invalidURL
        }
        
        let request = ChatRequest(
            message: message,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            stream: false
        )
        
        return try await performRequest(url: url, request: request, settings: settings)
    }
    
    func sendChatStream(
        message: String,
        settings: AppSettings,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        onChunk: @escaping (String) -> Void
    ) async throws -> ServerResponse {
        guard let url = URL(string: settings.streamURL) else {
            throw APIError.invalidURL
        }
        
        let request = ChatRequest(
            message: message,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            stream: true
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !settings.apiKey.isEmpty {
            urlRequest.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        }
        urlRequest.httpBody = try encoder.encode(request)
        urlRequest.timeoutInterval = settings.timeout
        
        let (asyncBytes, response) = try await session.bytes(for: urlRequest)
        try validateResponse(response)
        
        var fullResponse = ""
        var tokensGenerated = 0
        var startTime = Date()
        
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let data = line.dropFirst(6)
                if data == "[DONE]" {
                    break
                } else if data.hasPrefix("[ERROR]") {
                    let errorMsg = String(data.dropFirst(7))
                    throw APIError.serverError(errorMsg)
                } else {
                    let chunk = String(data)
                    fullResponse += chunk
                    tokensGenerated += chunk.split(separator: " ").count
                    onChunk(chunk)
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return ServerResponse(
            answer: fullResponse.trimmingCharacters(in: .whitespacesAndNewlines),
            tokensGenerated: tokensGenerated > 0 ? tokensGenerated : nil,
            durationSeconds: duration,
            tokensPerSecond: duration > 0 ? Double(tokensGenerated) / duration : nil
        )
    }
    
    // MARK: - Private Helpers
    
    private func performRequest<T: Encodable, R: Decodable>(
        url: URL,
        request: T,
        settings: AppSettings
    ) async throws -> R {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            urlRequest.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        }
        urlRequest.httpBody = try encoder.encode(request)
        urlRequest.timeoutInterval = settings.timeout
        
        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response)
        return try decoder.decode(R.self, from: data)
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 408, 504:
            throw APIError.timeout
        case 503:
            throw APIError.serviceUnavailable
        case 500...599:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case timeout
    case serviceUnavailable
    case serverError(String)
    case httpError(Int)
    case networkError(String)
    case decodingError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Invalid API key"
        case .timeout:
            return "Qwen took too long to respond"
        case .serviceUnavailable:
            return "AI server is offline"
        case .serverError(let msg):
            return "Server error: \(msg)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .decodingError(let msg):
            return "Data parsing error: \(msg)"
        case .unknown(let msg):
            return "Unknown error: \(msg)"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .timeout:
            return "Qwen took too long to respond."
        case .serviceUnavailable:
            return "AI server is offline."
        case .networkError:
            return "Cannot connect to Raspberry Pi."
        case .unauthorized:
            return "Invalid API key. Check settings."
        case .invalidURL:
            return "Invalid server address. Check settings."
        default:
            return errorDescription ?? "Connection error."
        }
    }
}