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
    @Published var isDeleteMode = false
    
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
        // Get user's preferred transcription language (default to device locale)
        let preferredLocale = getPreferredTranscriptionLocale()
        print("🎤 Using preferred locale: \(preferredLocale.identifier)")
        
        // Check if this locale is available and download if needed
        try await ensureModelAvailable(for: preferredLocale)
        
        speechTranscriber = SpeechTranscriber(
            locale: preferredLocale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        
        guard let transcriber = speechTranscriber else {
            throw TranscriptionError.failedToSetup
        }
        
        speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
        print("✅ SpeechTranscriber setup complete for \(preferredLocale.identifier)")
    }
    
    private func getPreferredTranscriptionLocale() -> Locale {
        // Check if user has manually selected a preferred language
        if let preferredLanguageCode = UserDefaults.standard.string(forKey: "PreferredTranscriptionLanguage") {
            let preferredLocale = Locale(identifier: preferredLanguageCode)
            print("🎤 Using user-selected language: \(preferredLanguageCode)")
            return preferredLocale
        }
        
        // Use device locale as default
        print("🎤 Using device locale: \(Locale.current.identifier)")
        return Locale.current
    }
    
    private func ensureModelAvailable(for locale: Locale) async throws {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let installedLocales = await SpeechTranscriber.installedLocales
        
        print("🎤 Checking availability for: \(locale.identifier)")
        print("🎤 Supported locales: \(supportedLocales.map { $0.identifier })")
        print("🎤 Installed locales: \(installedLocales.map { $0.identifier })")
        
        // Check if the locale is supported
        let isSupported = supportedLocales.contains { supportedLocale in
            supportedLocale.identifier == locale.identifier ||
            supportedLocale.language.languageCode == locale.language.languageCode
        }
        
        guard isSupported else {
            print("❌ Locale \(locale.identifier) not supported")
            throw TranscriptionError.localeNotSupported(locale.identifier)
        }
        
        // Check if the model is already installed
        let isInstalled = installedLocales.contains { installedLocale in
            installedLocale.identifier == locale.identifier ||
            installedLocale.language.languageCode == locale.language.languageCode
        }
        
        if isInstalled {
            print("✅ Language model already installed for \(locale.identifier)")
            return
        }
        
        // If supported but not installed, we need to show an error or download
        print("⚠️ Language model for \(locale.identifier) is supported but not installed")
        print("💡 User needs to download language model in Settings")
        
        // For now, throw an error with helpful message
        // In a production app, you might want to use AssetInventory to download automatically
        throw TranscriptionError.modelsNotInstalled(locale.identifier)
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
    
    // MARK: - Language Selection Functions
    
    func setPreferredTranscriptionLanguage(_ languageCode: String) {
        UserDefaults.standard.set(languageCode, forKey: "PreferredTranscriptionLanguage")
        print("🎤 Set preferred transcription language to: \(languageCode)")
    }
    
    func getAvailableLanguages() async -> [(String, String)] {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let installedLocales = await SpeechTranscriber.installedLocales
        
        // Common language mappings for user-friendly display
        let languageNames: [String: String] = [
            "en-US": "English (US)",
            "en-GB": "English (UK)",
            "en-AU": "English (Australia)",
            "en-IN": "English (India)",
            "zh-CN": "Chinese (Simplified)",
            "zh-TW": "Chinese (Traditional)",
            "zh-Hans": "Chinese (Simplified)",
            "zh-Hant": "Chinese (Traditional)",
            "ja-JP": "Japanese",
            "ko-KR": "Korean",
            "fr-FR": "French",
            "de-DE": "German",
            "es-ES": "Spanish",
            "it-IT": "Italian",
            "pt-BR": "Portuguese (Brazil)"
        ]
        
        var availableLanguages: [(String, String)] = []
        
        // Add installed languages first (these work immediately)
        for locale in installedLocales {
            let identifier = locale.identifier
            let displayName = languageNames[identifier] ?? locale.localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? identifier) ?? identifier
            availableLanguages.append((identifier, "✅ \(displayName)"))
        }
        
        // Add supported but not installed languages
        for locale in supportedLocales {
            let identifier = locale.identifier
            if !installedLocales.contains(where: { $0.identifier == identifier }) {
                let displayName = languageNames[identifier] ?? locale.localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? identifier) ?? identifier
                availableLanguages.append((identifier, "📥 \(displayName) (Download Required)"))
            }
        }
        
        return availableLanguages.sorted { $0.1 < $1.1 }
    }
    
    func getCurrentTranscriptionLanguage() -> String {
        return getPreferredTranscriptionLocale().identifier
    }
    
    func switchToChineseSimplified() {
        setPreferredTranscriptionLanguage("zh-CN")
    }
    
    func switchToChineseTraditional() {
        setPreferredTranscriptionLanguage("zh-TW")
    }
    
    func switchToEnglish() {
        setPreferredTranscriptionLanguage("en-US")
    }
    
    // MARK: - Delete Functions
    
    func enterDeleteMode() {
        // Stop any playback when entering delete mode
        stopPlayback()
        isDeleteMode = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🗑️ Entered delete mode")
    }
    
    func exitDeleteMode() {
        isDeleteMode = false
        print("🗑️ Exited delete mode")
    }
    
    func deleteVoiceNote(_ voiceNote: VoiceNote) {
        // Stop playback if this note is currently playing
        if currentlyPlayingId == voiceNote.id {
            stopPlayback()
        }
        
        // Delete the audio file
        let audioURL = getDocumentsDirectory().appendingPathComponent(voiceNote.audioFileName)
        do {
            if FileManager.default.fileExists(atPath: audioURL.path) {
                try FileManager.default.removeItem(at: audioURL)
                print("🗑️ Deleted audio file: \(voiceNote.audioFileName)")
            }
        } catch {
            print("❌ Failed to delete audio file: \(error.localizedDescription)")
        }
        
        // Remove from the array
        voiceNotes.removeAll { $0.id == voiceNote.id }
        saveVoiceNotes()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
        impactFeedback.impactOccurred()
        
        print("🗑️ Deleted voice note: \(voiceNote.title)")
        
        // Exit delete mode if no notes remain
        if voiceNotes.isEmpty {
            exitDeleteMode()
        }
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
    case localeNotSupported(String)
    case modelsNotInstalled(String)
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToSetup:
            return "Failed to setup speech transcriber"
        case .localeNotSupported(let language):
            return "Language '\(language)' is not supported for transcription on this device. Supported languages include English, Chinese (Simplified), French, German, Italian, Japanese, Korean, Portuguese (Brazil), and Spanish."
        case .modelsNotInstalled(let language):
            return "Language model for '\(language)' is not installed. To use Chinese transcription:\n\n1. Go to Settings > General > Keyboards\n2. Add Chinese keyboards if not already added\n3. Or try switching the app language to Chinese and restart\n\nAlternatively, you can record in English which should work immediately."
        case .transcriptionFailed:
            return "Transcription process failed. Please try recording again."
        }
    }
}