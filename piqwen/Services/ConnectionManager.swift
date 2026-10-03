//
//  ConnectionManager.swift
//  PiQwen
//
//  Manages connection state and monitoring for the Raspberry Pi server
//

import Foundation
import Combine
import SwiftUI

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var connectionState: ConnectionState = .unknown
    @Published var lastHealthCheck: Date?
    @Published var lastError: APIError?
    @Published var serverInfo: HealthResponse?
    
    private var settings: AppSettings?
    private var monitoringTimer: Timer?
    private let apiClient = APIClient.shared
    private let checkInterval: TimeInterval = 30.0
    
    enum ConnectionState: Equatable {
        case unknown
        case connecting
        case connected(HealthResponse)
        case disconnected(APIError?)
        case error(APIError)
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
        
        var displayText: String {
            switch self {
            case .unknown: return "Unknown"
            case .connecting: return "Connecting..."
            case .connected: return "Pi Connected"
            case .disconnected(let error): return error?.userFriendlyMessage ?? "Pi Offline"
            case .error(let error): return error.userFriendlyMessage
            }
        }
        
        var indicatorColor: Color {
            switch self {
            case .connected: return .green
            case .connecting: return .orange
            case .disconnected, .error: return .red
            case .unknown: return .gray
            }
        }
        
        var shortText: String {
            switch self {
            case .connected: return "● Connected"
            case .connecting: return "◐ Connecting"
            case .disconnected: return "○ Offline"
            case .error: return "✗ Error"
            case .unknown: return "? Unknown"
            }
        }
    }
    
    private init() {}
    
    func configure(with settings: AppSettings) {
        self.settings = settings
    }
    
    func startMonitoring() {
        stopMonitoring()
        checkConnection()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            self.checkConnection()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    func checkConnection() {
        guard let settings = settings else {
            connectionState = .error(.invalidURL)
            return
        }
        
        connectionState = .connecting
        
        Task {
            do {
                let health = try await apiClient.checkHealth(settings: settings)
                await MainActor.run {
                    self.connectionState = .connected(health)
                    self.serverInfo = health
                    self.lastHealthCheck = Date()
                    self.lastError = nil
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    self.connectionState = .disconnected(apiError)
                    self.lastError = apiError
                    self.lastHealthCheck = Date()
                }
            } catch {
                await MainActor.run {
                    let error = APIError.networkError(error.localizedDescription)
                    self.connectionState = .disconnected(error)
                    self.lastError = error
                    self.lastHealthCheck = Date()
                }
            }
        }
    }
    
    func forceReconnect() {
        checkConnection()
    }
}