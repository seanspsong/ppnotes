//
//  ContentView.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VoiceNotesViewModel()
    @State private var currentLanguageFlag: String = "🇺🇸" // Default to English
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if viewModel.isDeleteMode {
                                viewModel.exitDeleteMode()
                            }
                        }
                    
                    VStack(spacing: 0) {
                        // Voice Notes Grid
                        ScrollView {
                            if viewModel.voiceNotes.isEmpty && !viewModel.isAddingNewNote {
                                emptyStateView
                                    .frame(maxWidth: .infinity, minHeight: geometry.size.height - 200)
                            } else {
                                LazyVStack(spacing: 16) {
                                    // Recording/Processing card (shows while recording or processing)
                                    if viewModel.isAddingNewNote {
                                        HStack {
                                            ProcessingCard(isRecording: viewModel.isRecording)
                                                .transition(.scale.combined(with: .opacity))
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    
                                    // Existing voice notes
                                    GeometryReader { geometry in
                                        StaggeredGrid(
                                            items: viewModel.voiceNotes,
                                            spacing: 16,
                                            columns: 2
                                        ) { voiceNote, index in
                                            VoiceNoteCard(
                                                voiceNote: voiceNote, 
                                                index: index,
                                                isCurrentlyRecording: false, // No card animations during recording
                                                screenWidth: geometry.size.width,
                                                viewModel: viewModel
                                            )
                                            .id(voiceNote.id)
                                            .transition(.asymmetric(
                                                insertion: .scale.combined(with: .opacity),
                                                removal: .scale.combined(with: .opacity)
                                            ))
                                            .animation(.spring(response: 1.2, dampingFraction: 0.9), value: viewModel.voiceNotes.count)
                                        }
                                    }
                                    .frame(height: CGFloat(ceil(Double(viewModel.voiceNotes.count) / 2.0)) * 250)
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 80) // Bottom padding for floating button clearance
                                .animation(.spring(response: 1.0, dampingFraction: 0.85), value: viewModel.isAddingNewNote)
                                .animation(.spring(response: 1.2, dampingFraction: 0.9), value: viewModel.voiceNotes.count)
                            }
                        }
                        .clipped() // Prevent content from overflowing
                        .refreshable {
                            // Pull to refresh functionality
                            // TODO: Implement re-processing with latest LLM model
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
            .navigationTitle("PPnotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isDeleteMode {
                        Button("Done") {
                            viewModel.exitDeleteMode()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    } else {
                        NavigationLink(destination: SettingsView()) {
                            Text(currentLanguageFlag)
                                .font(.title2)
                        }
                    }
                }
            }
            .overlay(
                // Floating Recording Button (only on main content)
                VStack {
                    Spacer()
                    RecordingButton(viewModel: viewModel)
                        .padding(.bottom, 34) // Space from bottom edge
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            )
        }
        .preferredColorScheme(nil) // Adaptive to system
        .onAppear {
            loadCurrentLanguageFlag()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadCurrentLanguageFlag()
        }
        .overlay(
            // Card overlay for voice note detail (top layer)
            Group {
                if let selectedNote = viewModel.selectedNoteForDetail {
                    GeometryReader { screenGeometry in
                        ZStack {
                            // Semi-transparent background
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    print("🎬 Dismissing detail view...")
                                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                        viewModel.animateFromSource = false
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        viewModel.selectedNoteForDetail = nil
                                    }
                                }
                            
                            // Card view with zoom-from-source animation
                            VoiceNoteDetailView(voiceNote: selectedNote, viewModel: viewModel)
                                .frame(
                                    width: viewModel.animateFromSource ? 
                                        (screenGeometry.size.width - 40) : viewModel.sourceCardFrame.width,
                                    height: viewModel.animateFromSource ? 
                                        (screenGeometry.size.height - 80) : viewModel.sourceCardFrame.height
                                )
                                .scaleEffect(viewModel.animateFromSource ? 1.0 : 0.3)
                                .opacity(viewModel.animateFromSource ? 1.0 : 0.5)
                                .offset(
                                    x: viewModel.animateFromSource ? 0 : 
                                        (viewModel.sourceCardFrame.midX - screenGeometry.size.width / 2),
                                    y: viewModel.animateFromSource ? 0 : 
                                        (viewModel.sourceCardFrame.midY - screenGeometry.size.height / 2)
                                )
                                .onAppear {
                                    print("🎬 Detail view appeared, animateFromSource: \(viewModel.animateFromSource)")
                                    print("🎬 Source frame: \(viewModel.sourceCardFrame)")
                                    
                                    // Small delay to ensure the initial state is visible
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        print("🎬 Starting zoom animation...")
                                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                            viewModel.animateFromSource = true
                                        }
                                    }
                                }
                        }
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    private func loadCurrentLanguageFlag() {
        let languageCode = UserDefaults.standard.string(forKey: "PreferredTranscriptionLanguage") ?? "en-US"
        
        // Map language codes to flags (same as SupportedLanguage enum)
        switch languageCode {
        case "en-US", "en-GB", "en-AU", "en-IN":
            currentLanguageFlag = "🇺🇸"
        case "ja-JP":
            currentLanguageFlag = "🇯🇵"
        case "zh-CN", "zh-Hans", "zh-Hans-CN":
            currentLanguageFlag = "🇨🇳"
        case "zh-TW", "zh-Hant", "zh-Hant-TW":
            currentLanguageFlag = "🇹🇼"
        case "it-IT":
            currentLanguageFlag = "🇮🇹"
        case "de-DE":
            currentLanguageFlag = "🇩🇪"
        case "fr-FR":
            currentLanguageFlag = "🇫🇷"
        case "es-ES":
            currentLanguageFlag = "🇪🇸"
        default:
            currentLanguageFlag = "🇺🇸" // Default to English
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Empty state illustration
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Voice Notes Yet")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Press and hold the microphone button to record your first voice note")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// Processing Card shown while recording or creating new voice note
struct ProcessingCard: View {
    let isRecording: Bool
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status indicator
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(isRecording ? "Recording" : "Processing")
                        .font(.caption)
                        .foregroundColor(isRecording ? .red : .secondary)
                    
                    // Animated dots
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(isRecording ? Color.red : Color.secondary)
                                .frame(width: 4, height: 4)
                                .opacity(isAnimating ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                }
            }
            
            // Status title
            Text(isRecording ? "Recording..." : "Creating Voice Note...")
                .font(.headline)
                .foregroundColor(.primary)
                .opacity(0.7)
            
            Spacer()
            
            // Animated waveform
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isRecording ? Color.red.opacity(0.7) : Color.accentColor.opacity(0.6))
                        .frame(width: 2, height: 8)
                        .scaleEffect(
                            y: isAnimating ? CGFloat.random(in: 0.5...1.5) : 1.0
                        )
                        .animation(
                            .easeInOut(duration: 0.8 + Double(index) * 0.1)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 16)
            
            // Status message
            HStack {
                Text(isRecording ? "Hold to continue..." : "Processing...")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 170, height: 130)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((isRecording ? Color.red : Color.accentColor).opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            isAnimating = true
        }
    }
}



#Preview {
    ContentView()
}
