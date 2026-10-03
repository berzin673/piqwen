//
//  SpeechManager.swift
//  PiQwen
//
//  Handles speech recognition using watchOS built-in dictation
//

import Foundation
import Speech
import Combine
import SwiftUI

class SpeechManager: ObservableObject {
    static let shared = SpeechManager()
    
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var error: SpeechError?
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    enum SpeechError: LocalizedError, Equatable {
        case notAuthorized
        case notAvailable
        case audioEngineError(String)
        case recognitionError(String)
        case offlineMode
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Speech recognition not authorized"
            case .notAvailable: return "Speech recognition not available"
            case .audioEngineError(let msg): return "Audio error: \(msg)"
            case .recognitionError(let msg): return "Recognition error: \(msg)"
            case .offlineMode: return "Offline speech not available on this device"
            }
        }
    }
    
    private init() {
        // Try to create recognizer for current locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        self.speechRecognizer?.delegate = SpeechRecognizerDelegate(manager: self)
        
        checkAuthorization()
    }
    
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }
    
    var isAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable && authorizationStatus == .authorized
    }
    
    var supportsOfflineRecognition: Bool {
        guard let recognizer = speechRecognizer else { return false }
        // On watchOS, offline dictation availability varies by model and watchOS version
        // Series 6+ with watchOS 7+ generally support offline dictation
        return recognizer.supportsOnDeviceRecognition
    }
    
    func startRecording() throws {
        guard isAvailable else {
            if authorizationStatus != .authorized {
                throw SpeechError.notAuthorized
            }
            if !speechRecognizer!.isAvailable {
                throw SpeechError.notAvailable
            }
            throw SpeechError.offlineMode
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session for watchOS
        #if os(watchOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionError("Failed to create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Enable on-device recognition if available (offline)
        if #available(watchOS 10.0, *), supportsOfflineRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        recognizedText = ""
        error = nil
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.recognizedText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    self?.handleRecognitionError(error)
                }
                
                if result?.isFinal == true {
                    self?.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        #if os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        #endif
    }
    
    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError
        
        // Check for common offline/unavailable errors
        if nsError.domain == kAFAssistantErrorDomain {
            switch nsError.code {
            case 203, 209, 1110: // Offline/not available errors
                self.error = .offlineMode
            default:
                self.error = .recognitionError(error.localizedDescription)
            }
        } else {
            self.error = .recognitionError(error.localizedDescription)
        }
        
        stopRecording()
    }
    
    func cancelRecording() {
        stopRecording()
        recognizedText = ""
    }
}

// Delegate for speech recognizer availability changes
private class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
    weak var manager: SpeechManager?
    
    init(manager: SpeechManager) {
        self.manager = manager
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            // Availability changed - could notify UI
            print("Speech recognition availability changed: \(available)")
        }
    }
}