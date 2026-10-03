//
//  ResponseView.swift
//  PiQwen
//
//  Detailed response view with full answer display
//

import SwiftUI

struct ResponseView: View {
    let response: ServerResponse
    let originalQuestion: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Question
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                            Text("You")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        Text(originalQuestion)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    // Answer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.green)
                            Text("Qwen")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        Text(response.answer)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Metadata
                    if let tokens = response.tokensGenerated,
                       let duration = response.durationSeconds,
                       let tokPerSec = response.tokensPerSecond {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                StatItem(label: "Tokens", value: "\(tokens)")
                                Spacer()
                                StatItem(label: "Time", value: String(format: "%.1fs", duration))
                                Spacer()
                                StatItem(label: "Speed", value: String(format: "%.1f tok/s", tokPerSec))
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    private func copyToClipboard() {
        #if os(watchOS)
        // On watchOS, we can't easily copy to clipboard
        // This would require a different approach
        #else
        UIPasteboard.general.string = response.answer
        #endif
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    ResponseView(
        response: ServerResponse(
            answer: "25 × 4 = 100",
            tokensGenerated: 8,
            durationSeconds: 1.2,
            tokensPerSecond: 6.7
        ),
        originalQuestion: "What is 25 multiplied by 4?"
    )
}