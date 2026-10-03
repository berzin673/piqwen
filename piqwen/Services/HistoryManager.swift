//
//  HistoryManager.swift
//  PiQwen
//
//  Local chat history storage using JSON files on Apple Watch
//

import Foundation
import Combine
import SwiftUI

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    
    private let fileName = "conversations.json"
    private let fileManager = FileManager.default
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    private var fileURL: URL {
        documentsURL.appendingPathComponent(fileName)
    }
    
    private init() {
        loadConversations()
    }
    
    // MARK: - Public Methods
    
    func loadConversations() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Conversation].self, from: data)
            self.conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            // File doesn't exist or corrupted - start fresh
            self.conversations = []
        }
    }
    
    func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }
    
    func createConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        conversations.insert(conversation, at: 0)
        saveConversations()
        return conversation
    }
    
    func startNewConversation() {
        let conversation = createConversation()
        currentConversation = conversation
    }
    
    func addMessage(to conversation: Conversation, message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        
        var updatedConversation = conversations[index]
        updatedConversation.messages.append(message)
        updatedConversation.updatedAt = Date()
        
        // Auto-generate title from first user message
        if updatedConversation.title == "New Conversation",
           let firstUserMessage = updatedConversation.messages.first(where: { $0.role == .user }) {
            updatedConversation.title = String(firstUserMessage.content.prefix(30))
        }
        
        conversations[index] = updatedConversation
        saveConversations()
        
        if currentConversation?.id == conversation.id {
            currentConversation = updatedConversation
        }
    }
    
    func addMessageToCurrent(message: ChatMessage) {
        guard let current = currentConversation else {
            startNewConversation()
            addMessage(to: currentConversation!, message: message)
            return
        }
        addMessage(to: current, message: message)
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        saveConversations()
        
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
        }
    }
    
    func deleteConversation(at indexSet: IndexSet) {
        for index in indexSet {
            let conversation = conversations[index]
            if currentConversation?.id == conversation.id {
                currentConversation = nil
            }
        }
        conversations.remove(atOffsets: indexSet)
        saveConversations()
    }
    
    func clearAllHistory() {
        conversations.removeAll()
        currentConversation = nil
        saveConversations()
    }
    
    func updateConversationTitle(_ conversation: Conversation, title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index].title = title
        conversations[index].updatedAt = Date()
        saveConversations()
    }
    
    var conversationCount: Int {
        conversations.count
    }
    
    var totalMessages: Int {
        conversations.reduce(0) { $0 + $1.messages.count }
    }
}