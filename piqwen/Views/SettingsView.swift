//
//  SettingsView.swift
//  PiQwen
//
//  Settings screen for server configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showingTestResult = false
    @State private var testResult: String = ""
    @State private var isTesting = false
    
    var body: some View {
        Form {
            // Server Connection Section
            Section(header: Text("Server Connection")) {
                HStack {
                    Text("Server IP")
                    Spacer()
                    TextField("192.168.4.1", text: $appSettings.serverIP)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .onChange(of: appSettings.serverIP) { _, _ in
                            connectionManager.configure(with: appSettings)
                        }
                }
                
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("8000", value: $appSettings.serverPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                        .keyboardType(.numberPad)
                        .onChange(of: appSettings.serverPort) { _, _ in
                            connectionManager.configure(with: appSettings)
                        }
                }
                
                HStack {
                    Text("Timeout")
                    Spacer()
                    TextField("60", value: $appSettings.timeout, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("Optional", text: $appSettings.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                
                Toggle("Auto-connect", isOn: $appSettings.autoConnect)
            }
            
            // Model Info Section
            Section(header: Text("Model")) {
                HStack {
                    Text("Model")
                    Spacer()
                    Text(appSettings.modelName)
                        .foregroundColor(.secondary)
                }
                
                if let health = connectionManager.serverInfo {
                    HStack {
                        Text("Server Model")
                        Spacer()
                        Text(health.model)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(health.device)
                            .foregroundColor(.secondary)
                    }
                    if let uptime = health.uptimeSeconds {
                        HStack {
                            Text("Uptime")
                            Spacer()
                            Text(formatUptime(uptime))
                                .foregroundColor(.secondary)
                        }
                    }
                    if let memory = health.memoryUsageMb {
                        HStack {
                            Text("Memory")
                            Spacer()
                            Text(String(format: "%.0f MB", memory))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Connection Test Section
            Section(header: Text("Connection Test")) {
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                    }
                }
                .disabled(isTesting)
                
                if !testResult.isEmpty {
                    HStack {
                        Image(systemName: testResult.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(testResult.contains("Success") ? .green : .red)
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Platform")
                    Spacer()
                    Text("watchOS")
                        .foregroundColor(.secondary)
                }
                
                Link("PiQwen Documentation", destination: URL(string: "https://github.com/yourusername/piqwen")!)
            }
            
            // Danger Zone
            Section(header: Text("Danger Zone")) {
                Button(role: .destructive) {
                    appSettings.resetToDefaults()
                    connectionManager.configure(with: appSettings)
                    connectionManager.forceReconnect()
                } label: {
                    Text("Reset to Defaults")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func testConnection() {
        isTesting = true
        testResult = ""
        
        Task {
            do {
                let response = try await APIClient.shared.testConnection(settings: appSettings)
                await MainActor.run {
                    self.testResult = "Success: \(response.message)"
                    self.isTesting = false
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    self.testResult = "Failed: \(apiError.userFriendlyMessage)"
                    self.isTesting = false
                }
            } catch {
                await MainActor.run {
                    self.testResult = "Failed: \(error.localizedDescription)"
                    self.isTesting = false
                }
            }
        }
    }
    
    private func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .environmentObject(ConnectionManager())
}