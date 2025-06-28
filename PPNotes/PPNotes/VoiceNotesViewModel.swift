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
import UIKit

@MainActor
class VoiceNotesViewModel: NSObject, ObservableObject {
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordingTimer: Timer?
    @Published var isAddingNewNote = false
    @Published var currentlyPlayingId: UUID?
    @Published var playbackProgress: Double = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
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
    
    override init() {
        super.init()
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
        
        // Show processing card immediately when recording starts
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isAddingNewNote = true
        }
        
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
            // If recording fails, hide the processing card
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAddingNewNote = false
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if let audioURL = audioRecorder?.url, recordingTime > 0.5 {
            // Only create voice note if recording is longer than 0.5 seconds
            createVoiceNote(from: audioURL, duration: recordingTime)
        } else {
            // If recording too short, just hide the processing card
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAddingNewNote = false
            }
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
        
        // Brief delay to show processing state, then replace processing card with actual voice note
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.voiceNotes.insert(voiceNote, at: 0)
                self.isAddingNewNote = false
            }
            self.saveVoiceNotes()
        }
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
    
    // MARK: - Playback Functions
    
    func playVoiceNote(_ voiceNote: VoiceNote) {
        // If same note is playing, pause it
        if currentlyPlayingId == voiceNote.id {
            pausePlayback()
            return
        }
        
        // Stop any current playback
        stopPlayback()
        
        // Get audio file URL
        let audioURL = getDocumentsDirectory().appendingPathComponent(voiceNote.audioFileName)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Audio file not found: \(audioURL.path)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentlyPlayingId = voiceNote.id
            playbackProgress = 0
            
            audioPlayer?.play()
            startPlaybackTimer()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentlyPlayingId = nil
        playbackProgress = 0
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let player = self.audioPlayer else { return }
                
                if player.isPlaying {
                    self.playbackProgress = player.currentTime / player.duration
                } else {
                    self.stopPlayback()
                }
            }
        }
    }
    
    func getCurrentVoiceNote() -> VoiceNote? {
        guard let playingId = currentlyPlayingId else { return nil }
        return voiceNotes.first { $0.id == playingId }
    }
}

// MARK: - AVAudioPlayerDelegate
extension VoiceNotesViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player error: \(error?.localizedDescription ?? "Unknown error")")
        stopPlayback()
    }
} 