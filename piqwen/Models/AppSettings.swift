//
//  AppSettings.swift
//  PiQwen
//
//  Application settings with local persistence
//

import Foundation
import Combine
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // Settings keys
    private enum Keys {
        static let serverIP = "server_ip"
        static let serverPort = "server_port"
        static let timeout = "timeout"
        static let apiKey = "api_key"
        static let autoConnect = "auto_connect"
        static let modelName = "model_name"
    }
    
    @Published var serverIP: String {
        didSet { UserDefaults.standard.set(serverIP, forKey: Keys.serverIP) }
    }
    
    @Published var serverPort: Int {
        didSet { UserDefaults.standard.set(serverPort, forKey: Keys.serverPort) }
    }
    
    @Published var timeout: TimeInterval {
        didSet { UserDefaults.standard.set(timeout, forKey: Keys.timeout) }
    }
    
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }
    
    @Published var autoConnect: Bool {
        didSet { UserDefaults.standard.set(autoConnect, forKey: Keys.autoConnect) }
    }
    
    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: Keys.modelName) }
    }
    
    private init() {
        self.serverIP = UserDefaults.standard.string(forKey: Keys.serverIP) ?? "192.168.4.1"
        self.serverPort = UserDefaults.standard.integer(forKey: Keys.serverPort) > 0 ? 
            UserDefaults.standard.integer(forKey: Keys.serverPort) : 8000
        self.timeout = UserDefaults.standard.double(forKey: Keys.timeout) > 0 ? 
            UserDefaults.standard.double(forKey: Keys.timeout) : 60.0
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""
        self.autoConnect = UserDefaults.standard.bool(forKey: Keys.autoConnect)
        self.modelName = UserDefaults.standard.string(forKey: Keys.modelName) ?? "Qwen2.5 2B"
    }
    
    var baseURL: String {
        "http://\(serverIP):\(serverPort)"
    }
    
    var healthURL: String {
        "\(baseURL)/health"
    }
    
    var chatURL: String {
        "\(baseURL)/chat"
    }
    
    var streamURL: String {
        "\(baseURL)/chat/stream"
    }
    
    var testURL: String {
        "\(baseURL)/test"
    }
    
    func resetToDefaults() {
        serverIP = "192.168.4.1"
        serverPort = 8000
        timeout = 60.0
        apiKey = ""
        autoConnect = true
        modelName = "Qwen2.5 2B"
    }
}