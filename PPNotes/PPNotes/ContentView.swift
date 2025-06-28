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
                            if viewModel.voiceNotes.isEmpty {
                                emptyStateView
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                StaggeredGrid(
                                    items: viewModel.voiceNotes,
                                    spacing: 16,
                                    columns: 2
                                ) { voiceNote, index in
                                    VoiceNoteCard(voiceNote: voiceNote, index: index)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                .padding(.top, 20)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.voiceNotes.count)
                            }
                        }
                        .refreshable {
                            // Pull to refresh functionality
                            // TODO: Implement re-processing with latest LLM model
                        }
                        
                        Spacer()
                        
                        // Recording Button Area
                        VStack {
                            RecordingButton(viewModel: viewModel)
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                        .background(
                            // Semi-transparent background for button area
                            Color(.systemBackground)
                                .opacity(0.95)
                                .blur(radius: 10)
                        )
                    }
                }
            }
            .navigationTitle("PPNotes")
            .navigationBarTitleDisplayMode(.large)
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
