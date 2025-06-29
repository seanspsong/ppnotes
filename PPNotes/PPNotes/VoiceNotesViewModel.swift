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
    @Published var selectedNoteForDetail: VoiceNote?
    @Published var isGeneratingTitle = false
    @Published var titleGenerationProgress: Double = 0.0
    @Published var sourceCardFrame: CGRect = .zero
    @Published var animateFromSource = false
    
    private var pausedNoteId: UUID?
    
    // Title Generation Service
    private lazy var titleGenerationService = TitleGenerationService()
    
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
        
        let audioURL = getDocumentsDirectory().appendingPathComponent(generateUniqueFileName())
        
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
        var preferredLocale = getPreferredTranscriptionLocale()
        print("🎤 Using preferred locale: \(preferredLocale.identifier)")
        
        // Check if SpeechTranscriber is available first
        let supportedLocales = await SpeechTranscriber.supportedLocales
        if supportedLocales.isEmpty {
            print("⚠️ SpeechTranscriber not available, will use SFSpeechRecognizer only")
            // Just validate that SFSpeechRecognizer works
            try await ensureModelAvailable(for: preferredLocale)
            return
        }
        
        // Try to ensure SpeechTranscriber model is available, with fallback to English
        do {
            try await ensureModelAvailable(for: preferredLocale)
        } catch TranscriptionError.localeNotSupported {
            // Fallback to English if preferred locale not supported
            print("🔄 Falling back to English (en-US)")
            preferredLocale = Locale(identifier: "en-US")
            try await ensureModelAvailable(for: preferredLocale)
        } catch TranscriptionError.modelsNotInstalled {
            // If models not installed, try English as fallback
            if preferredLocale.identifier != "en-US" {
                print("🔄 Trying English fallback due to missing models")
                preferredLocale = Locale(identifier: "en-US")
                try await ensureModelAvailable(for: preferredLocale)
            } else {
                // If even English models aren't installed, rethrow
                throw TranscriptionError.modelsNotInstalled(preferredLocale.identifier)
            }
        }
        
        // Only set up SpeechTranscriber if models are available
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
        
        // Normalize device locale format for SpeechTranscriber compatibility
        let deviceLocaleId = Locale.current.identifier
        let normalizedLocaleId = normalizeLocaleIdentifier(deviceLocaleId)
        
        print("🎤 Using device locale: \(deviceLocaleId) → normalized: \(normalizedLocaleId)")
        return Locale(identifier: normalizedLocaleId)
    }
    
    private func normalizeLocaleIdentifier(_ identifier: String) -> String {
        // Convert underscore to hyphen (en_US → en-US)
        let hyphenized = identifier.replacingOccurrences(of: "_", with: "-")
        
        // Map common device locales to SpeechTranscriber expected formats
        let localeMapping: [String: String] = [
            "en-US": "en-US",
            "en-GB": "en-GB", 
            "en-AU": "en-AU",
            "en-IN": "en-IN",
            "zh-Hans": "zh-CN",  // Chinese Simplified mapping
            "zh-Hant": "zh-TW",  // Chinese Traditional mapping
            "zh-Hans-US": "zh-CN",
            "zh-Hant-US": "zh-TW",
            "ja-JP": "ja-JP",
            "ko-KR": "ko-KR",
            "fr-FR": "fr-FR",
            "de-DE": "de-DE",
            "es-ES": "es-ES",
            "it-IT": "it-IT",
            "pt-BR": "pt-BR"
        ]
        
        // Return mapped locale or fall back to language code mapping
        if let mapped = localeMapping[hyphenized] {
            return mapped
        }
        
        // Fallback: extract language code and map to most common variant
        let languageCode = String(hyphenized.prefix(2))
        
        switch languageCode {
        case "en": return "en-US"
        case "zh": 
            // Check for traditional vs simplified hints
            if hyphenized.contains("Hant") || hyphenized.contains("TW") || hyphenized.contains("HK") {
                return "zh-TW"
            } else {
                return "zh-CN"
            }
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "it": return "it-IT"
        case "pt": 
            if hyphenized.contains("BR") {
                return "pt-BR"
            } else {
                return "pt-BR"  // Default to Brazil variant
            }
        default: return hyphenized
        }
    }
    
    private func ensureModelAvailable(for locale: Locale) async throws {
        print("🎤 Checking availability for: \(locale.identifier)")
        
        // Use SFSpeechRecognizer to check for supported locales (more reliable than SpeechTranscriber API)
        let speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // Check if SFSpeechRecognizer can be created for this locale
        guard let recognizer = speechRecognizer else {
            print("❌ SFSpeechRecognizer could not be created for locale: \(locale.identifier)")
            
            // Try creating with just language code
            let languageCode = locale.language.languageCode?.identifier ?? "en"
            let fallbackLocale = Locale(identifier: languageCode)
            let fallbackRecognizer = SFSpeechRecognizer(locale: fallbackLocale)
            
            guard fallbackRecognizer != nil else {
                print("❌ Fallback SFSpeechRecognizer also failed for: \(languageCode)")
                throw TranscriptionError.localeNotSupported(locale.identifier)
            }
            
            print("✅ Using fallback language code: \(languageCode)")
            return
        }
        
        // Check if the recognizer is available
        guard recognizer.isAvailable else {
            print("❌ SFSpeechRecognizer not available for locale: \(locale.identifier)")
            throw TranscriptionError.modelsNotInstalled(locale.identifier)
        }
        
        print("✅ SFSpeechRecognizer is available for \(locale.identifier)")
        
        // Also check SpeechTranscriber availability (iOS 26+ feature)
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let installedLocales = await SpeechTranscriber.installedLocales
        
        // If SpeechTranscriber lists are empty, we'll rely on SFSpeechRecognizer validation above
        if supportedLocales.isEmpty {
            // Don't log this as it's expected in many cases
            return
        }
        
        print("🎤 SpeechTranscriber supported locales: \(supportedLocales.map { $0.identifier })")
        print("🎤 SpeechTranscriber installed locales: \(installedLocales.map { $0.identifier })")
        
        // Enhanced locale matching for SpeechTranscriber
        let isSupported = supportedLocales.contains { supportedLocale in
            supportedLocale.identifier == locale.identifier ||
            supportedLocale.language.languageCode == locale.language.languageCode ||
            supportedLocale.identifier.hasPrefix(locale.language.languageCode?.identifier ?? "") ||
            locale.identifier.hasPrefix(supportedLocale.language.languageCode?.identifier ?? "")
        }
        
        guard isSupported else {
            print("❌ Locale \(locale.identifier) not supported by SpeechTranscriber")
            throw TranscriptionError.localeNotSupported(locale.identifier)
        }
        
        // Check installation status
        let isInstalled = installedLocales.contains { installedLocale in
            installedLocale.identifier == locale.identifier ||
            installedLocale.language.languageCode == locale.language.languageCode ||
            installedLocale.identifier.hasPrefix(locale.language.languageCode?.identifier ?? "") ||
            locale.identifier.hasPrefix(installedLocale.language.languageCode?.identifier ?? "")
        }
        
        if isInstalled {
            print("✅ SpeechTranscriber language model already installed for \(locale.identifier)")
        } else {
            print("⚠️ SpeechTranscriber language model for \(locale.identifier) is supported but not installed")
            print("💡 User needs to download language model in Settings")
            throw TranscriptionError.modelsNotInstalled(locale.identifier)
        }
    }
    
    private func transcribeAudio(audioURL: URL, voiceNoteId: UUID) async {
        // Check speech recognition permission
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("Speech recognition not authorized")
            await updateVoiceNoteWithAITitle(
                voiceNoteId: voiceNoteId,
                transcription: "",
                fallbackTitle: "Voice Note"
            )
            return
        }
        
        do {
            await MainActor.run {
                isTranscribing = true
            }
            
            // Setup transcriber
            try await setupTranscriber()
            
            // Check if SpeechTranscriber was set up or if we should use legacy API directly
            let transcriptionText: String
            if let transcriber = speechTranscriber, let analyzer = speechAnalyzer {
                // Try modern SpeechTranscriber API
                transcriptionText = try await performTranscription(
                    audioURL: audioURL,
                    transcriber: transcriber,
                    analyzer: analyzer
                )
            } else {
                // Use legacy SFSpeechRecognizer directly
                print("🎤 Using SFSpeechRecognizer for transcription")
                transcriptionText = try await performLegacyTranscription(audioURL: audioURL)
            }
            
            // Update the voice note with transcription and generate intelligent title
            await MainActor.run {
                isTranscribing = false
            }
            
            await updateVoiceNoteWithAITitle(
                voiceNoteId: voiceNoteId,
                transcription: transcriptionText
            )
            
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            if let transcriptionError = error as? TranscriptionError {
                print("Error type: \(transcriptionError)")
            }
            
            await MainActor.run {
                isTranscribing = false
            }
            
            // Update with fallback title
            await updateVoiceNoteWithAITitle(
                voiceNoteId: voiceNoteId,
                transcription: "",
                fallbackTitle: "Voice Note"
            )
        }
    }
    
    private func performTranscription(
        audioURL: URL,
        transcriber: SpeechTranscriber,
        analyzer: SpeechAnalyzer
    ) async throws -> String {
        
        do {
            // Try the new iOS 26 SpeechTranscriber API first
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
            
        } catch {
            // Only log unexpected errors, not format compatibility issues
            if !error.localizedDescription.contains("Audio format is not supported") {
                print("⚠️ SpeechTranscriber failed, falling back to SFSpeechRecognizer: \(error)")
            }
            
            // Fallback to older, more reliable SFSpeechRecognizer API
            return try await performLegacyTranscription(audioURL: audioURL)
        }
    }
    
    private func performLegacyTranscription(audioURL: URL) async throws -> String {
        let preferredLocale = getPreferredTranscriptionLocale()
        
        guard let speechRecognizer = SFSpeechRecognizer(locale: preferredLocale) else {
            throw TranscriptionError.localeNotSupported(preferredLocale.identifier)
        }
        
        guard speechRecognizer.isAvailable else {
            throw TranscriptionError.modelsNotInstalled(preferredLocale.identifier)
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed)
                    return
                }
                
                if result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    // MARK: - AI-Powered Title Generation
    
    private func updateVoiceNoteWithAITitle(
        voiceNoteId: UUID,
        transcription: String,
        fallbackTitle: String? = nil
    ) async {
        guard let index = voiceNotes.firstIndex(where: { $0.id == voiceNoteId }) else {
            return
        }
        
        // First update with transcription and temporary title
        let temporaryTitle = !transcription.isEmpty ? "Generating title..." : (fallbackTitle ?? "Voice Note")
        
        await MainActor.run {
            voiceNotes[index] = VoiceNote(
                id: voiceNotes[index].id,
                title: temporaryTitle,
                audioFileName: voiceNotes[index].audioFileName,
                duration: voiceNotes[index].duration,
                timestamp: voiceNotes[index].timestamp,
                transcription: transcription
            )
            saveVoiceNotes()
        }
        
        // If we have transcription text, generate an intelligent title
        if !transcription.isEmpty {
            print("🚀 [ViewModel] Transcription completed - triggering title generation")
            print("🚀 [ViewModel] Note ID: \(voiceNoteId)")
            print("🚀 [ViewModel] Transcription preview: '\(String(transcription.prefix(50)))...'")
            await generateAndUpdateTitle(voiceNoteId: voiceNoteId, transcription: transcription)
        } else {
            print("🚀 [ViewModel] ⚠️ No transcription text available - skipping title generation")
        }
    }
    
    private func generateAndUpdateTitle(voiceNoteId: UUID, transcription: String) async {
        print("🎯 [ViewModel] Starting title generation for note \(voiceNoteId)")
        print("🎯 [ViewModel] Transcription length: \(transcription.count) characters")
        
        await MainActor.run {
            isGeneratingTitle = true
            titleGenerationProgress = 0.0
        }
        
        let startTime = Date()
        
        // Generate intelligent title using smart NLP techniques
        print("🎯 [ViewModel] Calling TitleGenerationService...")
        let generatedTitle = await titleGenerationService.generateTitle(from: transcription)
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("🎯 [ViewModel] Title generation completed in \(String(format: "%.2f", totalTime))s")
        print("🎯 [ViewModel] Generated title: '\(generatedTitle ?? "nil")'")
        
        // Mirror the progress from the service
        await MainActor.run {
            titleGenerationProgress = titleGenerationService.titleGenerationProgress
        }
        
        // Update the voice note with the generated title
        await MainActor.run {
            guard let index = voiceNotes.firstIndex(where: { $0.id == voiceNoteId }) else {
                print("🎯 [ViewModel] ❌ Error: Could not find voice note with ID \(voiceNoteId)")
                isGeneratingTitle = false
                titleGenerationProgress = 0.0
                return
            }
            
            let finalTitle = generatedTitle ?? generateFallbackTitle(from: transcription)
            
            if generatedTitle == nil {
                print("🎯 [ViewModel] ⚠️ Using fallback title: '\(finalTitle)'")
            } else {
                print("🎯 [ViewModel] ✅ Using generated title: '\(finalTitle)'")
            }
            
            voiceNotes[index] = VoiceNote(
                id: voiceNotes[index].id,
                title: finalTitle,
                audioFileName: voiceNotes[index].audioFileName,
                duration: voiceNotes[index].duration,
                timestamp: voiceNotes[index].timestamp,
                transcription: voiceNotes[index].transcription
            )
            
            saveVoiceNotes()
            isGeneratingTitle = false
            titleGenerationProgress = 0.0
            
            print("🎯 [ViewModel] ✅ Title generation process completed for note \(voiceNoteId)")
        }
    }
    
    private func generateFallbackTitle(from transcription: String) -> String {
        print("🚨 [ViewModel] Generating fallback title from transcription")
        
        let words = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        print("🚨 [ViewModel] Fallback: Found \(words.count) words in transcription")
        
        if words.isEmpty {
            print("🚨 [ViewModel] Fallback: No words found, using default 'Voice Note'")
            return "Voice Note"
        }
        
        // Take first 3-4 words for title
        let titleWords = Array(words.prefix(4))
        let title = titleWords.joined(separator: " ")
        
        print("🚨 [ViewModel] Fallback: Selected words: \(titleWords)")
        
        // Capitalize first letter and limit length
        let capitalizedTitle = title.prefix(1).capitalized + title.dropFirst()
        
        // Truncate if too long
        let finalTitle: String
        if capitalizedTitle.count > 30 {
            finalTitle = String(capitalizedTitle.prefix(27)) + "..."
            print("🚨 [ViewModel] Fallback: Truncated long title")
        } else {
            finalTitle = capitalizedTitle
        }
        
        print("🚨 [ViewModel] Fallback: Final title: '\(finalTitle)'")
        return finalTitle
    }
    
    // MARK: - Batch Title Generation for Existing Notes
    
    func generateTitlesForExistingNotes() async {
        let notesWithoutTitles = voiceNotes.filter { 
            !$0.transcription.isEmpty && ($0.title.isEmpty || $0.title == "Voice Note" || $0.title == "Processing...")
        }
        
        guard !notesWithoutTitles.isEmpty else { return }
        
        let generatedTitles = await titleGenerationService.generateTitlesForNotes(notesWithoutTitles)
        
        await MainActor.run {
            for (noteId, title) in generatedTitles {
                if let index = voiceNotes.firstIndex(where: { $0.id == noteId }) {
                    voiceNotes[index] = VoiceNote(
                        id: voiceNotes[index].id,
                        title: title,
                        audioFileName: voiceNotes[index].audioFileName,
                        duration: voiceNotes[index].duration,
                        timestamp: voiceNotes[index].timestamp,
                        transcription: voiceNotes[index].transcription
                    )
                }
            }
            saveVoiceNotes()
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func generateUniqueFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let dateTimeString = formatter.string(from: Date())
        
        let baseFileName = "ppnotes-\(dateTimeString)"
        let documentsDir = getDocumentsDirectory()
        
        // Find the next available counter (starting from 01)
        var counter = 1
        var fileName: String
        
        repeat {
            let counterString = String(format: "%02d", counter)
            fileName = "\(baseFileName)-rec\(counterString).m4a"
            let fileURL = documentsDir.appendingPathComponent(fileName)
            
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                break
            }
            
            counter += 1
        } while counter <= 999 // Safety limit
        
        return fileName
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