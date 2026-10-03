//
//  PiQwenApp.swift
//  PiQwen
//
//  Independent watchOS app for local AI communication with Raspberry Pi
//

import SwiftUI

@main
struct PiQwenApp: App {
    @StateObject private var appSettings = AppSettings()
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var historyManager = HistoryManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .environmentObject(connectionManager)
                .environmentObject(historyManager)
                .onAppear {
                    // Initialize connections
                    connectionManager.configure(with: appSettings)
                    connectionManager.startMonitoring()
                }
        }
    }
}