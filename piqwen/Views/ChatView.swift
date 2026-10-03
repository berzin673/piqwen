//
//  ChatView.swift
//  PiQwen
//
//  Main chat interface for asking questions
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var historyManager: HistoryManager
    @StateObject private var speechManager = SpeechManager.shared
    @StateObject private var apiClient = APIClient.shared
    
    @State private var inputText = ""
    @State private var isSending = false
    @State private var showingResponse = false
    @State private var lastResponse: ServerResponse?
    @State private var errorMessage: String?
    @State private var streamingText = ""
    @State private var isStreaming = false
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending &&
        connectionManager.connectionState.isConnected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection status bar
            ConnectionStatusBar()
            
            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if let currentConv = historyManager.currentConversation {
                            ForEach(currentConv.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        // Streaming response indicator
                        if isStreaming && !streamingText.isEmpty {
                            MessageBubble(
                                message: ChatMessage(
                                    role: .assistant,
                                    content: streamingText
                                )
                            )
                            .id("streaming")
                        }
                        
                        // Loading indicator
                        if isSending && !isStreaming {
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Thinking...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
                .onChange(of: historyManager.currentConversation?.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: streamingText) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isSending) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Error message banner
            if let error = errorMessage {
                ErrorBanner(message: error) {
                    errorMessage = nil
                }
            }
            
            // Input area
            InputArea(
                inputText: $inputText,
                isSending: $isSending,
                canSend: canSend,
                onSend: sendMessage,
                onVoiceInput: startVoiceInput
            )
        }
        .navigationTitle("PiQwen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    historyManager.startNewConversation()
                } label: {
                    Image(systemName: "plus.message")
                }
                .disabled(isSending)
            }
        }
        .sheet(isPresented: $showingResponse) {
            if let response = lastResponse {
                ResponseView(response: response, originalQuestion: inputText)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if isSending {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastMessage = historyManager.currentConversation?.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }
        
        inputText = ""
        isSending = true
        isStreaming = true
        streamingText = ""
        errorMessage = nil
        
        // Add user message to history immediately
        let userMessage = ChatMessage(role: .user, content: message)
        historyManager.addMessageToCurrent(message: userMessage)
        
        Task {
            do {
                // Try streaming first
                let response = try await apiClient.sendChatStream(
                    message: message,
                    settings: appSettings,
                    onChunk: { chunk in
                        DispatchQueue.main.async {
                            self.streamingText += chunk
                        }
                    }
                )
                
                await MainActor.run {
                    self.isStreaming = false
                    self.isSending = false
                    self.streamingText = ""
                    
                    // Add assistant response to history
                    let assistantMessage = ChatMessage(
                        role: .assistant,
                        content: response.answer,
                        tokensGenerated: response.tokensGenerated,
                        durationSeconds: response.durationSeconds
                    )
                    self.historyManager.addMessageToCurrent(message: assistantMessage)
                }
                
            } catch let apiError as APIError {
                await MainActor.run {
                    self.isStreaming = false
                    self.isSending = false
                    self.streamingText = ""
                    self.errorMessage = apiError.userFriendlyMessage
                }
            } catch {
                await MainActor.run {
                    self.isStreaming = false
                    self.isSending = false
                    self.streamingText = ""
                    self.errorMessage = APIError.networkError(error.localizedDescription).userFriendlyMessage
                }
            }
        }
    }
    
    private func startVoiceInput() {
        do {
            try speechManager.startRecording()
            
            // Monitor for recognized text
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                DispatchQueue.main.async {
                    if !speechManager.recognizedText.isEmpty && !speechManager.isRecording {
                        self.inputText = speechManager.recognizedText
                        timer.invalidate()
                    } else if !speechManager.isRecording {
                        timer.invalidate()
                    }
                }
            }
        } catch let error as SpeechManager.SpeechError {
            errorMessage = error.userFriendlyMessage
        } catch {
            errorMessage = "Voice input failed: \(error.localizedDescription)"
        }
    }
}

struct ConnectionStatusBar: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionManager.connectionState.indicatorColor)
                .frame(width: 8, height: 8)
            
            Text(connectionManager.connectionState.shortText)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if case .connected(let health) = connectionManager.connectionState {
                Text(health.model)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
    }
}

struct InputArea: View {
    @Binding var inputText: String
    @Binding var isSending: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onVoiceInput: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Voice input button
                Button(action: onVoiceInput) {
                    Image(systemName: SpeechManager.shared.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(SpeechManager.shared.isRecording ? .red : .primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .disabled(isSending || !SpeechManager.shared.isAvailable)
                
                // Text input field
                TextField("Ask Qwen...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isFocused)
                    .lineLimit(3)
                    .disabled(isSending)
                    .onSubmit {
                        if canSend { onSend() }
                    }
                
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if message.role == .user {
                Spacer(minLength: 30)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                // Role indicator
                HStack(spacing: 4) {
                    if message.role == .assistant {
                        Image(systemName: "cpu")
                            .font(.caption2)
                    }
                    Text(message.role.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(message.role.color)
                
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.blue.opacity(0.15) : Color(.systemGray5))
                    )
                
                // Metadata
                if let tokens = message.tokensGenerated, let duration = message.durationSeconds {
                    HStack(spacing: 8) {
                        Text("\(tokens) tokens")
                        Text(String(format: "%.1fs", duration))
                        if duration > 0 {
                            Text(String(format: "%.1f tok/s", Double(tokens) / duration))
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 30)
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppSettings())
        .environmentObject(ConnectionManager())
        .environmentObject(HistoryManager())
}