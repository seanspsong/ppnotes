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
import Speech

@MainActor
class VoiceNotesViewModel: NSObject, ObservableObject {
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordingTimer: Timer?
    @Published var isAddingNewNote = false
    @Published var currentlyPlayingId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var isTranscribing = false
    
    private var pausedNoteId: UUID?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var speechTranscriber: SpeechTranscriber?
    private var speechAnalyzer: SpeechAnalyzer?
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
        requestPermissions()
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
        
        // Check microphone permission
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            print("Microphone permission not granted")
            return
        }
        
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
        let fileName = audioURL.lastPathComponent
        
        // Create initial voice note with empty transcription
        let voiceNote = VoiceNote(
            title: "Processing...",
            audioFileName: fileName,
            duration: duration,
            timestamp: Date(),
            transcription: ""
        )
        
        // Add the voice note immediately and start transcription
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            voiceNotes.insert(voiceNote, at: 0)
            isAddingNewNote = false
        }
        saveVoiceNotes()
        
        // Start transcription process
        Task {
            await transcribeAudio(audioURL: audioURL, voiceNoteId: voiceNote.id)
        }
    }
    
    // MARK: - Permission Functions
    
    private func requestPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied")
            }
        }
        
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition permission granted")
            case .denied:
                print("Speech recognition permission denied")
            case .restricted:
                print("Speech recognition restricted")
            case .notDetermined:
                print("Speech recognition permission not determined")
            @unknown default:
                print("Unknown speech recognition permission status")
            }
        }
    }
    
    // MARK: - Transcription Functions
    
    private func setupTranscriber() async throws {
        // Check if models are available and get the best locale to use
        let bestLocale = try await ensureModelsAvailable()
        
        speechTranscriber = SpeechTranscriber(
            locale: bestLocale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        
        guard let transcriber = speechTranscriber else {
            throw TranscriptionError.failedToSetup
        }
        
        speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
    }
    
    private func ensureModelsAvailable() async throws -> Locale {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let installedLocales = await SpeechTranscriber.installedLocales
        let currentLocale = Locale.current
        
        print("Current device locale: \(currentLocale.identifier)")
        print("Supported locales: \(supportedLocales.map { $0.identifier })")
        print("Installed locales: \(installedLocales.map { $0.identifier })")
        
        // First try the current locale
        if supportedLocales.contains(where: { $0.identifier == currentLocale.identifier }) {
            if installedLocales.contains(where: { $0.identifier == currentLocale.identifier }) {
                print("Using device locale: \(currentLocale.identifier)")
                return currentLocale
            } else {
                print("Device locale supported but not installed: \(currentLocale.identifier)")
            }
        } else {
            print("Device locale not supported: \(currentLocale.identifier)")
        }
        
        // Fall back to English (US) if current locale not supported
        let englishLocale = Locale(identifier: "en-US")
        if supportedLocales.contains(where: { $0.identifier == englishLocale.identifier }) {
            if installedLocales.contains(where: { $0.identifier == englishLocale.identifier }) {
                print("Falling back to English (US) for transcription")
                return englishLocale
            }
        }
        
        // Try any available English variant
        let englishVariants = ["en-US", "en-GB", "en-AU", "en-IN"]
        for variant in englishVariants {
            let locale = Locale(identifier: variant)
            if supportedLocales.contains(where: { $0.identifier == locale.identifier }) {
                if installedLocales.contains(where: { $0.identifier == locale.identifier }) {
                    print("Falling back to \(variant) for transcription")
                    return locale
                }
            }
        }
        
        // If no English variants available, try the first available locale
        for supportedLocale in supportedLocales {
            if installedLocales.contains(where: { $0.identifier == supportedLocale.identifier }) {
                print("Using first available locale: \(supportedLocale.identifier)")
                return supportedLocale
            }
        }
        
        throw TranscriptionError.localeNotSupported
    }
    
    private func transcribeAudio(audioURL: URL, voiceNoteId: UUID) async {
        // Check speech recognition permission
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("Speech recognition not authorized")
            await MainActor.run {
                updateVoiceNoteWithTranscription(
                    voiceNoteId: voiceNoteId,
                    transcription: "",
                    fallbackTitle: "Voice Note"
                )
            }
            return
        }
        
        do {
            await MainActor.run {
                isTranscribing = true
            }
            
            // Setup transcriber
            try await setupTranscriber()
            
            guard let transcriber = speechTranscriber,
                  let analyzer = speechAnalyzer else {
                throw TranscriptionError.failedToSetup
            }
            
            // Create transcription task
            let transcriptionText = try await performTranscription(
                audioURL: audioURL,
                transcriber: transcriber,
                analyzer: analyzer
            )
            
            // Update the voice note with transcription
            await MainActor.run {
                updateVoiceNoteWithTranscription(
                    voiceNoteId: voiceNoteId,
                    transcription: transcriptionText
                )
                isTranscribing = false
            }
            
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            if let transcriptionError = error as? TranscriptionError {
                print("Error type: \(transcriptionError)")
            }
            
            await MainActor.run {
                // Update with fallback title
                updateVoiceNoteWithTranscription(
                    voiceNoteId: voiceNoteId,
                    transcription: "",
                    fallbackTitle: "Voice Note"
                )
                isTranscribing = false
            }
        }
    }
    
    private func performTranscription(
        audioURL: URL,
        transcriber: SpeechTranscriber,
        analyzer: SpeechAnalyzer
    ) async throws -> String {
        
        // Create an AVAudioFile from the URL
        let audioFile = try AVAudioFile(forReading: audioURL)
        
        // Collect all transcription results
        async let transcriptionFuture = transcriber.results
            .reduce(into: "") { result, transcriptionResult in
                result += transcriptionResult.text.description
            }
        
        // Start analyzing the audio file
        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        
        return try await transcriptionFuture
    }
    
    private func updateVoiceNoteWithTranscription(
        voiceNoteId: UUID,
        transcription: String,
        fallbackTitle: String? = nil
    ) {
        guard let index = voiceNotes.firstIndex(where: { $0.id == voiceNoteId }) else {
            return
        }
        
        let title: String
        if !transcription.isEmpty {
            // Generate title from first few words of transcription
            title = generateTitleFromTranscription(transcription)
        } else {
            title = fallbackTitle ?? "Voice Note"
        }
        
        voiceNotes[index] = VoiceNote(
            id: voiceNotes[index].id,
            title: title,
            audioFileName: voiceNotes[index].audioFileName,
            duration: voiceNotes[index].duration,
            timestamp: voiceNotes[index].timestamp,
            transcription: transcription
        )
        
        saveVoiceNotes()
    }
    
    private func generateTitleFromTranscription(_ transcription: String) -> String {
        let words = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if words.isEmpty {
            return "Voice Note"
        }
        
        // Take first 2-3 words for title
        let titleWords = Array(words.prefix(3))
        let title = titleWords.joined(separator: " ")
        
        // Capitalize first letter and limit length
        let capitalizedTitle = title.prefix(1).capitalized + title.dropFirst()
        
        // Truncate if too long
        if capitalizedTitle.count > 25 {
            return String(capitalizedTitle.prefix(22)) + "..."
        }
        
        return capitalizedTitle
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
        
        // If same note is paused, resume it
        if pausedNoteId == voiceNote.id && audioPlayer != nil {
            resumePlayback()
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
            pausedNoteId = nil
            playbackProgress = 0
            
            audioPlayer?.play()
            startPlaybackTimer()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            print("Error playing audio: \(error)")
            stopPlayback()
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
        pausedNoteId = currentlyPlayingId
        currentlyPlayingId = nil
    }
    
    func resumePlayback() {
        guard let player = audioPlayer,
              let pausedId = pausedNoteId else {
            stopPlayback()
            return
        }
        
        currentlyPlayingId = pausedId
        pausedNoteId = nil
        player.play()
        startPlaybackTimer()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentlyPlayingId = nil
        pausedNoteId = nil
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
    
    func isNotePaused(_ noteId: UUID) -> Bool {
        return pausedNoteId == noteId
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

// MARK: - Transcription Errors
enum TranscriptionError: Error, LocalizedError {
    case failedToSetup
    case localeNotSupported
    case modelsNotInstalled
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToSetup:
            return "Failed to setup speech transcriber"
        case .localeNotSupported:
            return "No supported languages available for transcription. Please ensure iOS 26 speech models are installed."
        case .modelsNotInstalled:
            return "Speech recognition models not installed. Please download language models in Settings > General > Keyboard & Dictation."
        case .transcriptionFailed:
            return "Transcription process failed"
        }
    }
}