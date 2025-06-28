//
//  VoiceNotesViewModel.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class VoiceNotesViewModel: ObservableObject {
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordingTimer: Timer?
    
    private var audioRecorder: AVAudioRecorder?
    private let maxRecordingTime: TimeInterval = 180 // 3 minutes
    private let warningTime: TimeInterval = 10 // 10 seconds warning
    
    var remainingTime: TimeInterval {
        max(0, maxRecordingTime - recordingTime)
    }
    
    var isWarningTime: Bool {
        remainingTime <= warningTime
    }
    
    var isNearWarningTime: Bool {
        remainingTime <= 30 // 30 seconds
    }
    
    var formattedRemainingTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init() {
        setupAudioSession()
        loadVoiceNotes()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        let audioURL = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            startTimer()
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if let audioURL = audioRecorder?.url {
            createVoiceNote(from: audioURL, duration: recordingTime)
        }
        
        recordingTime = 0
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.recordingTime += 0.1
                
                // Check for vibration warning
                if self.remainingTime <= self.warningTime && self.remainingTime > (self.warningTime - 0.1) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
                
                // Auto-stop at max time
                if self.recordingTime >= self.maxRecordingTime {
                    self.stopRecording()
                }
            }
        }
    }
    
    private func createVoiceNote(from audioURL: URL, duration: TimeInterval) {
        // For now, create a simple title and empty transcription
        // In a real app, this would use on-device LLM for transcription
        let title = "Voice Note"
        let fileName = audioURL.lastPathComponent
        
        let voiceNote = VoiceNote(
            title: title,
            audioFileName: fileName,
            duration: duration,
            timestamp: Date(),
            transcription: ""
        )
        
        voiceNotes.insert(voiceNote, at: 0)
        saveVoiceNotes()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveVoiceNotes() {
        if let encoded = try? JSONEncoder().encode(voiceNotes) {
            UserDefaults.standard.set(encoded, forKey: "SavedVoiceNotes")
        }
    }
    
    private func loadVoiceNotes() {
        if let data = UserDefaults.standard.data(forKey: "SavedVoiceNotes"),
           let decoded = try? JSONDecoder().decode([VoiceNote].self, from: data) {
            voiceNotes = decoded
        }
    }
} 