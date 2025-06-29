//
//  VoiceNoteCard.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI
import UIKit

struct VoiceNoteCard: View {
    let voiceNote: VoiceNote
    let index: Int
    let isCurrentlyRecording: Bool
    let screenWidth: CGFloat
    @ObservedObject var viewModel: VoiceNotesViewModel
    @State private var animationTrigger = false
    @State private var shakeOffset: CGFloat = 0
    
    private var isPlaying: Bool {
        viewModel.currentlyPlayingId == voiceNote.id
    }
    
    private var isPaused: Bool {
        viewModel.isNotePaused(voiceNote.id)
    }
    
    // Random slight rotation for staggered effect
    private var rotation: Double {
        let rotations: [Double] = [-5, -3, -1, 0, 1, 3, 5]
        return rotations[index % rotations.count]
    }
    
    // Responsive card width based on screen size
    private func cardWidth(for screenWidth: CGFloat) -> CGFloat {
        // Calculate available width for 2 columns with spacing and padding
        let totalSpacing: CGFloat = 16 + 32 // grid spacing + StaggeredGrid horizontal padding
        let availableWidth = screenWidth - totalSpacing
        let baseWidth = availableWidth / 2
        
        // Add slight variation for staggered effect
        let variations: [CGFloat] = [-6, 3, -3, 6, 0]
        let variation = variations[index % variations.count]
        
        return max(140, baseWidth + variation) // Minimum width of 140
    }
    
    private var cardHeight: CGFloat {
        let heights: [CGFloat] = [180, 200, 190, 210, 220]
        return heights[index % heights.count]
    }
    
    private func staticBarHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 10, 4, 12, 8, 5, 9, 7, 11, 6, 8, 4, 10, 9, 7, 5, 12, 6, 8, 10]
        return heights[index % heights.count]
    }
    
    private func waveformColor(for index: Int, isActive: Bool) -> Color {
        if isCurrentlyRecording {
            return Color.accentColor
        } else if isActive {
            return Color.accentColor.opacity(0.8)
        } else {
            return Color.secondary.opacity(0.6)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            cardContent
                .contentShape(Rectangle())
                .simultaneousGesture(
                    viewModel.isDeleteMode ? nil : TapGesture()
                        .onEnded {
                            // Capture the card's position in global coordinates
                            let globalFrame = geometry.frame(in: .global)
                            viewModel.sourceCardFrame = globalFrame
                            
                            // Reset animation state and then show detail view
                            viewModel.animateFromSource = false
                            viewModel.selectedNoteForDetail = voiceNote
                            
                            print("🎯 Tapped card at position: \(globalFrame)")
                        }
                )
                .simultaneousGesture(
                    viewModel.isDeleteMode ? nil : LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            print("🗑️ Long press detected, entering delete mode")
                            viewModel.enterDeleteMode()
                        }
                )
        }
        .padding(14)
        .frame(width: cardWidth(for: screenWidth), height: cardHeight)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .rotationEffect(.degrees(rotation))
        .offset(x: shakeOffset)
        .overlay(
            // Delete button overlay
            Group {
                if viewModel.isDeleteMode {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                viewModel.deleteVoiceNote(voiceNote)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                            .scaleEffect(1.2)
                            .offset(x: 8, y: -8)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        )
        .scaleEffect(viewModel.isDeleteMode ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isDeleteMode)
        .onChange(of: viewModel.isDeleteMode) { _, isDeleteMode in
            if isDeleteMode {
                startShaking()
            } else {
                stopShaking()
            }
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with date and time
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(voiceNote.displayDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(voiceNote.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Auto-generated title
            HStack {
                Text(voiceNote.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show AI title generation indicator
                if viewModel.isGeneratingTitle && voiceNote.title == "Generating title..." {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .opacity(0.7)
                        
                        // Progress indicator
                        if viewModel.titleGenerationProgress > 0 {
                            ProgressView(value: viewModel.titleGenerationProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                .frame(width: 25, height: 2)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .scaleEffect(0.5)
                        }
                    }
                }
            }
            
            // Transcription text (if available)
            if !voiceNote.transcription.isEmpty {
                Text(voiceNote.transcription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 2)
            } else if viewModel.isTranscribing {
                HStack(spacing: 4) {
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Animated dots
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 3, height: 3)
                                .scaleEffect(animationTrigger ? 1.2 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: animationTrigger
                                )
                        }
                    }
                }
                .padding(.vertical, 2)
                .onAppear {
                    animationTrigger = true
                }
            }
            
            Spacer()
            
            // Waveform visualization with playback progress
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { barIndex in
                    let progressThreshold = Double(barIndex) / 20.0
                    let isBarActive = isPlaying && viewModel.playbackProgress > progressThreshold
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(waveformColor(for: barIndex, isActive: isBarActive))
                        .frame(
                            width: 2, 
                            height: staticBarHeight(for: barIndex)
                        )
                        .scaleEffect(
                            y: isCurrentlyRecording ? 
                                (animationTrigger ? 1.5 : 0.5) : 1.0
                        )
                        .animation(
                            isCurrentlyRecording ? 
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : 
                                .easeOut(duration: 0.3), 
                            value: isCurrentlyRecording
                        )
                        .animation(
                            isCurrentlyRecording ? 
                                .easeInOut(duration: 0.8 + Double(barIndex) * 0.1).repeatForever(autoreverses: true) : 
                                .none,
                            value: animationTrigger
                        )
                }
            }
            .frame(height: 16)
            .onChange(of: isCurrentlyRecording) { _, newValue in
                if newValue {
                    animationTrigger.toggle()
                } else {
                    animationTrigger = false
                }
            }
            
            Spacer(minLength: 8)
            
            // Duration badge with playback progress and play button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceNote.formattedDuration)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    if isPlaying {
                        Text("\(Int(viewModel.playbackProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Play/Pause button in bottom right corner
                Button(action: {
                    viewModel.playVoiceNote(voiceNote)
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .scaleEffect((isPlaying || isPaused) ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isPlaying)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func startShaking() {
        withAnimation(
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        ) {
            shakeOffset = 2
        }
    }
    
    private func stopShaking() {
        withAnimation(.easeOut(duration: 0.1)) {
            shakeOffset = 0
        }
    }
}

#Preview {
    VoiceNoteCard(
        voiceNote: VoiceNote(
            title: "Meeting Notes",
            audioFileName: "test.m4a",
            duration: 125.5,
            timestamp: Date(),
            transcription: ""
        ),
        index: 0,
        isCurrentlyRecording: false,
        screenWidth: UIScreen.main.bounds.width,
        viewModel: VoiceNotesViewModel()
    )
    .padding()
} 