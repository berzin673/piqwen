//
//  HistoryView.swift
//  PiQwen
//
//  Chat history view
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: Conversation?
    @State private var editingConversation: Conversation?
    @State private var newTitle = ""
    
    var body: some View {
        List {
            if historyManager.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Start a new chat to create history")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(historyManager.conversations) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        isCurrent: historyManager.currentConversation?.id == conversation.id,
                        onTap: { historyManager.currentConversation = conversation },
                        onEdit: { startEditing(conversation) },
                        onDelete: { confirmDelete(conversation) }
                    )
                }
                .onDelete(perform: deleteConversations)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !historyManager.conversations.isEmpty {
                    Button("Clear All", role: .destructive) {
                        confirmClearAll()
                    }
                }
            }
        }
        .alert("Delete Conversation?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { conversationToDelete = nil }
            Button("Delete", role: .destructive) {
                if let conv = conversationToDelete {
                    historyManager.deleteConversation(conv)
                }
                conversationToDelete = nil
            }
        } message: {
            Text("This will permanently delete the conversation.")
        }
        .alert("Rename Conversation", isPresented: .constant(editingConversation != nil)) {
            TextField("Title", text: $newTitle)
            Button("Cancel") { cancelEditing() }
            Button("Save") { saveTitle() }
        } message: {
            Text("Enter a new title for this conversation.")
        }
        .alert("Clear All History?", isPresented: .constant(showingClearAllAlert)) {
            Button("Cancel", role: .cancel) { showingClearAllAlert = false }
            Button("Clear All", role: .destructive) {
                historyManager.clearAllHistory()
                showingClearAllAlert = false
            }
        } message: {
            Text("This will permanently delete all conversations.")
        }
    }
    
    @State private var showingClearAllAlert = false
    
    private func confirmClearAll() {
        showingClearAllAlert = true
    }
    
    private func startEditing(_ conversation: Conversation) {
        editingConversation = conversation
        newTitle = conversation.title
    }
    
    private func cancelEditing() {
        editingConversation = nil
        newTitle = ""
    }
    
    private func saveTitle() {
        if let conv = editingConversation {
            historyManager.updateConversationTitle(conv, title: newTitle)
        }
        cancelEditing()
    }
    
    private func confirmDelete(_ conversation: Conversation) {
        conversationToDelete = conversation
        showingDeleteAlert = true
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        historyManager.deleteConversation(at: offsets)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isCurrent: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Current indicator
                if isCurrent {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 8, height: 8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(conversation.title)
                            .font(.body)
                            .fontWeight(isCurrent ? .semibold : .regular)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(conversation.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(conversation.preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(conversation.messageCount) messages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            if !isCurrent {
                Button(action: onTap) {
                    Label("Open", systemImage: "arrow.right")
                }
                .tint(.green)
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(HistoryManager())
}