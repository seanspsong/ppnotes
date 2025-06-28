//
//  ContentView.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VoiceNotesViewModel()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Voice Notes Grid
                        ScrollView {
                            if viewModel.voiceNotes.isEmpty && !viewModel.isAddingNewNote {
                                emptyStateView
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                    StaggeredGrid(
                                        items: viewModel.voiceNotes,
                                        spacing: 16,
                                        columns: 2
                                    ) { voiceNote, index in
                                        VoiceNoteCard(
                                            voiceNote: voiceNote, 
                                            index: index,
                                            isCurrentlyRecording: false // No card animations during recording
                                        )
                                        .id(voiceNote.id)
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.voiceNotes.count)
                                    }
                                }
                                .padding(.top, 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isAddingNewNote)
                            }
                        }
                        .refreshable {
                            // Pull to refresh functionality
                            // TODO: Implement re-processing with latest LLM model
                        }
                        
                        Spacer()
                        
                        // Recording Button Area
                        VStack {
                            Spacer()
                                .frame(height: 40)
                            RecordingButton(viewModel: viewModel)
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 30)
                        .background(
                            // Semi-transparent background for button area
                            Color(.systemBackground)
                                .opacity(0.95)
                                .blur(radius: 10)
                        )
                    }
                }
            }
            .navigationTitle("PPnotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .preferredColorScheme(nil) // Adaptive to system
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

// Placeholder Settings View
struct SettingsView: View {
    var body: some View {
        List {
            Section("Recording") {
                HStack {
                    Text("Recording Quality")
                    Spacer()
                    Text("High")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Transcription") {
                HStack {
                    Text("Language")
                    Spacer()
                    Text("English")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Privacy") {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All data stays on device")
                }
                .foregroundColor(.secondary)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
