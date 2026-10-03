//
//  ChatMessage.swift
//  PiQwen
//
//  Data models for chat messages and history
//

import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let tokensGenerated: Int?
    let durationSeconds: Double?
    
    init(role: MessageRole, content: String, tokensGenerated: Int? = nil, durationSeconds: Double? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.tokensGenerated = tokensGenerated
        self.durationSeconds = durationSeconds
    }
    
    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .user: return "You"
            case .assistant: return "Qwen"
            case .system: return "System"
            }
        }
        
        var color: Color {
            switch self {
            case .user: return .blue
            case .assistant: return .green
            case .system: return .orange
            }
        }
    }
}

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Conversation", messages: [ChatMessage] = []) {
        self.id = UUID()
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var preview: String {
        messages.last?.content ?? "Empty conversation"
    }
    
    var messageCount: Int {
        messages.count
    }
}

struct ServerResponse: Codable {
    let answer: String
    let tokensGenerated: Int?
    let durationSeconds: Double?
    let tokensPerSecond: Double?
    
    enum CodingKeys: String, CodingKey {
        case answer
        case tokensGenerated = "tokens_generated"
        case durationSeconds = "duration_seconds"
        case tokensPerSecond = "tokens_per_second"
    }
}

struct HealthResponse: Codable {
    let status: String
    let model: String
    let device: String
    let version: String?
    let uptimeSeconds: Double?
    let memoryUsageMb: Double?
    
    enum CodingKeys: String, CodingKey {
        case status, model, device, version
        case uptimeSeconds = "uptime_seconds"
        case memoryUsageMb = "memory_usage_mb"
    }
    
    var isHealthy: Bool {
        status.lowercased() == "ok"
    }
}

struct TestResponse: Codable {
    let message: String
}

struct ConfigResponse: Codable {
    let model: String
    let nCtx: Int
    let maxTokens: Int
    let temperature: Double
    let nThreads: Int
    let serverPort: Int
    let wifiSsid: String
    
    enum CodingKeys: String, CodingKey {
        case model
        case nCtx = "n_ctx"
        case maxTokens = "max_tokens"
        case temperature
        case nThreads = "n_threads"
        case serverPort = "server_port"
        case wifiSsid = "wifi_ssid"
    }
}

struct ErrorResponse: Codable {
    let error: String
    let detail: String?
}