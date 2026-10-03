//
//  ContentView.swift
//  PiQwen
//
//  Main app view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var historyManager: HistoryManager
    @State private var selectedTab = 0
    @State private var showingNewChat = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Chat View
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chat")
            }
            .tag(0)
            
            // History View
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Image(systemName: "clock.fill")
                Text("History")
            }
            .tag(1)
            
            // Status View
            NavigationStack {
                StatusView()
            }
            .tabItem {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text("Status")
            }
            .tag(2)
            
            // Settings View
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .onAppear {
            // Start new conversation if none selected
            if historyManager.currentConversation == nil && !historyManager.conversations.isEmpty {
                historyManager.currentConversation = historyManager.conversations[0]
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(ConnectionManager())
        .environmentObject(HistoryManager())
}