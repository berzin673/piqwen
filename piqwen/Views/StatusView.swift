//
//  StatusView.swift
//  PiQwen
//
//  Detailed connection status and server information
//

import SwiftUI

struct StatusView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var appSettings: AppSettings
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            // Connection Status Section
            Section(header: Text("Connection Status")) {
                HStack {
                    Circle()
                        .fill(connectionManager.connectionState.indicatorColor)
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connectionManager.connectionState.displayText)
                            .font(.headline)
                        Text(connectionManager.connectionState.shortText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                
                if let lastCheck = connectionManager.lastHealthCheck {
                    HStack {
                        Text("Last Check")
                        Spacer()
                        Text(lastCheck, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = connectionManager.lastError {
                    HStack {
                        Text("Last Error")
                        Spacer()
                        Text(error.userFriendlyMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Button(action: refreshConnection) {
                    HStack {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRefreshing ? "Refreshing..." : "Refresh Connection")
                    }
                }
                .disabled(isRefreshing)
            }
            
            // Server Information Section
            if let health = connectionManager.serverInfo {
                Section(header: Text("Server Information")) {
                    InfoRow(label: "Model", value: health.model)
                    InfoRow(label: "Device", value: health.device)
                    InfoRow(label: "Version", value: health.version ?? "Unknown")
                    InfoRow(label: "Status", value: health.status.capitalized)
                    
                    if let uptime = health.uptimeSeconds {
                        InfoRow(label: "Uptime", value: formatUptime(uptime))
                    }
                    
                    if let memory = health.memoryUsageMb {
                        InfoRow(label: "Memory Usage", value: String(format: "%.0f MB", memory))
                    }
                }
            }
            
            // Network Configuration Section
            Section(header: Text("Network Configuration")) {
                InfoRow(label: "Server IP", value: appSettings.serverIP)
                InfoRow(label: "Port", value: "\(appSettings.serverPort)")
                InfoRow(label: "Base URL", value: appSettings.baseURL)
                InfoRow(label: "Timeout", value: String(format: "%.0fs", appSettings.timeout))
                InfoRow(label: "API Key", value: appSettings.apiKey.isEmpty ? "Not set" : "Configured")
            }
            
            // Wi-Fi Information Section
            Section(header: Text("Wi-Fi Network")) {
                InfoRow(label: "SSID", value: "PiQwen")
                InfoRow(label: "Expected IP", value: "192.168.4.1")
                InfoRow(label: "Connect Apple Watch to", value: "PiQwen Wi-Fi network")
            }
            
            // Troubleshooting Section
            Section(header: Text("Troubleshooting")) {
                NavigationLink("Connection Guide") {
                    TroubleshootingView()
                }
                
                Link("PiQwen GitHub", destination: URL(string: "https://github.com/yourusername/piqwen")!)
            }
        }
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshConnectionAsync()
        }
    }
    
    private func refreshConnection() {
        isRefreshing = true
        connectionManager.forceReconnect()
        
        // Give it a moment to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
        }
    }
    
    private func refreshConnectionAsync() async {
        connectionManager.forceReconnect()
        // Wait for connection check to complete
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }
    
    private func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct TroubleshootingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Connection Troubleshooting")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("If your Apple Watch cannot connect to the Raspberry Pi:")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        StepRow(number: 1, text: "Ensure Raspberry Pi is powered on and booted completely (wait 60s after power)")
                        StepRow(number: 2, text: "Connect Apple Watch to 'PiQwen' Wi-Fi network")
                        StepRow(number: 3, text: "Verify password matches what you set during setup")
                        StepRow(number: 4, text: "Open PiQwen app and check Status tab")
                        StepRow(number: 5, text: "Tap 'Test Connection' in Settings")
                        StepRow(number: 6, text: "If still failing, reboot Raspberry Pi")
                    }
                }
                
                Divider()
                
                Group {
                    Text("Common Issues")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    IssueRow(
                        title: "Pi Offline",
                        description: "Raspberry Pi not booted or Wi-Fi hotspot not started. Check Pi LED activity."
                    )
                    IssueRow(
                        title: "Wrong IP",
                        description: "Server IP in Settings must match Pi's hotspot IP (default 192.168.4.1)."
                    )
                    IssueRow(
                        title: "Timeout",
                        description: "Qwen2.5 2B on 4GB Pi may take 10-30s for first response. Increase timeout in Settings."
                    )
                    IssueRow(
                        title: "API Key Mismatch",
                        description: "If you set an API key on the Pi, enter the same key in Apple Watch Settings."
                    )
                }
                
                Divider()
                
                Group {
                    Text("Offline Requirements")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RequirementRow(text: "✓ No internet required during use")
                        RequirementRow(text: "✓ No iPhone required during use")
                        RequirementRow(text: "✓ Raspberry Pi creates own Wi-Fi hotspot")
                        RequirementRow(text: "✓ All AI inference runs locally on Pi")
                        RequirementRow(text: "✓ Chat history stored on Apple Watch")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.body)
        }
    }
}

struct IssueRow: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct RequirementRow: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
    }
}

#Preview {
    StatusView()
        .environmentObject(ConnectionManager())
        .environmentObject(AppSettings())
}