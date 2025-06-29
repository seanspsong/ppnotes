//
//  TitleGenerationService.swift
//  PPNotes
//
//  Created by Sean Song on 1/25/25.
//

import Foundation
import Combine
import FoundationModels

// MARK: - Smart Title Generation Service
class TitleGenerationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isGeneratingTitle = false
    @Published var titleGenerationProgress: Double = 0.0
    
    // MARK: - Title Generation
    func generateTitle(from transcription: String) async -> String? {
        print("🧠 [TitleGen] Starting title generation")
        print("🧠 [TitleGen] Input transcription length: \(transcription.count) characters")
        print("🧠 [TitleGen] Input preview: \(String(transcription.prefix(100)))...")
        
        guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🧠 [TitleGen] ❌ Empty transcription, returning nil")
            return nil
        }
        
        let startTime = Date()
        
        await MainActor.run {
            isGeneratingTitle = true
            titleGenerationProgress = 0.0
        }
        
        print("🧠 [TitleGen] Starting smart title generation...")
        
        // Simulate AI processing with smart extraction
        let generatedTitle = await generateSmartTitle(from: transcription)
        
        let processingTime = Date().timeIntervalSince(startTime)
        print("🧠 [TitleGen] ✅ Title generation completed in \(String(format: "%.2f", processingTime))s")
        print("🧠 [TitleGen] Final title: '\(generatedTitle ?? "nil")'")
        
        await MainActor.run {
            isGeneratingTitle = false
            titleGenerationProgress = 0.0
        }
        
        return generatedTitle
    }
    
    private func generateSmartTitle(from transcription: String) async -> String? {
        print("🧠 [TitleGen] Phase 1: Analyzing text structure...")
        // Update progress
        await MainActor.run { titleGenerationProgress = 0.3 }
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        print("🧠 [TitleGen] Phase 2: Applying Apple Foundation Models...")
        await MainActor.run { titleGenerationProgress = 0.6 }
        
        // Use Apple Foundation Models for intelligent title extraction
        let smartTitle = await extractIntelligentTitle(from: transcription)
        
        print("🧠 [TitleGen] Phase 3: Finalizing title...")
        await MainActor.run { titleGenerationProgress = 1.0 }
        
        // Brief completion delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return smartTitle
    }
    
    private func extractIntelligentTitle(from transcription: String) async -> String {
        print("🧠 [TitleGen] 🔍 Starting Apple Foundation Models title generation")
        
        let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🧠 [TitleGen] 📝 Input text length: \(text.count) characters")
        
        // Use Apple Foundation Models for intelligent title generation
        if let llmTitle = await generateTitleWithAppleLLM(from: text) {
            print("🧠 [TitleGen] ✅ Apple LLM generated title: '\(llmTitle)'")
            return llmTitle
        }
        
        // Fallback to simple extraction if LLM fails
        print("🧠 [TitleGen] ⚠️ Apple LLM failed, using fallback extraction")
        return generateFallbackTitle(from: text)
    }
    
    private func generateTitleWithAppleLLM(from text: String) async -> String? {
        print("🧠 [TitleGen] 🤖 Initializing Apple Foundation Models session")
        
        // Check if Foundation Models is available
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            print("🧠 [TitleGen] ❌ Foundation Models not available")
            return nil
        }
        
        // Limit input length for efficiency (Apple recommends staying under 800 tokens)
        let inputText = String(text.prefix(800))
        print("🧠 [TitleGen] 📝 Using input text: '\(inputText)'")
        
        do {
            // Create a session with specific instructions for title generation
            let session = LanguageModelSession(
                instructions: """
                You are a helpful assistant that generates concise, meaningful titles for voice notes. 
                Create titles that are 8-10 words maximum and capture the main topic or action. 
                Avoid generic words like "note", "recording", "voice". 
                Focus on the key content and make it specific and informative.
                """
            )
            
            let prompt = """
            Generate a short, descriptive title for this voice note transcription. 
            The title should be concise (8-10 words max) and capture the main topic or action.
            
            Transcription: "\(inputText)"
            
            Respond with only the title, no additional text.
            """
            
            print("🧠 [TitleGen] 🤖 Sending prompt to Apple Foundation Models...")
            
            // Use the actual Apple Foundation Models async API
            let response = try await session.respond(to: prompt)
            
            let cleanTitle = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "Title:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanTitle.isEmpty && cleanTitle.count <= 50 {
                print("🧠 [TitleGen] ✅ Apple LLM response: '\(cleanTitle)'")
                return limitTitle(cleanTitle)
            } else {
                print("🧠 [TitleGen] ⚠️ Apple LLM response too long or empty: '\(cleanTitle)'")
                return nil
            }
            
        } catch {
            print("🧠 [TitleGen] ❌ Apple Foundation Models error: \(error)")
            return nil
        }
    }
    
    private func generateFallbackTitle(from text: String) -> String {
        print("🧠 [TitleGen] 📝 Using fallback title generation")
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }
        
        let meaningfulWords = Array(words.prefix(5))
        
        if meaningfulWords.isEmpty {
            return "Voice Note"
        }
        
        let result = limitTitle(meaningfulWords.joined(separator: " "))
        print("🧠 [TitleGen] 📝 Fallback result: '\(result)'")
        return result
    }
    
    private func limitTitle(_ title: String) -> String {
        let capitalizedTitle = title.prefix(1).capitalized + title.dropFirst()
        
        if capitalizedTitle.count > 35 {
            return String(capitalizedTitle.prefix(32)) + "..."
        }
        
        return capitalizedTitle
    }
    
    // MARK: - Batch Title Generation
    func generateTitlesForNotes(_ notes: [VoiceNote]) async -> [UUID: String] {
        var generatedTitles: [UUID: String] = [:]
        
        for note in notes {
            if note.title.isEmpty && !note.transcription.isEmpty {
                if let title = await generateTitle(from: note.transcription) {
                    generatedTitles[note.id] = title
                }
            }
        }
        
        return generatedTitles
    }
} 