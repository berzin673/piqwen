// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PiQwen",
    platforms: [
        .watchOS(.v10)
    ],
    products: [
        .executable(name: "PiQwen", targets: ["PiQwen"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PiQwen",
            dependencies: [],
            path: ".",
            sources: [
                "PiQwenApp.swift",
                "Models/ChatMessage.swift",
                "Models/AppSettings.swift",
                "Services/APIClient.swift",
                "Services/ConnectionManager.swift",
                "Services/SpeechManager.swift",
                "Services/HistoryManager.swift",
                "Views/ContentView.swift",
                "Views/ChatView.swift",
                "Views/ResponseView.swift",
                "Views/HistoryView.swift",
                "Views/SettingsView.swift",
                "Views/StatusView.swift",
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Combine"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
            ]
        ),
    ]
)