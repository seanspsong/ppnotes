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
    @ObservedObject var viewModel: VoiceNotesViewModel
    @State private var animationTrigger = false
    
    private var isPlaying: Bool {
        viewModel.currentlyPlayingId == voiceNote.id
    }
    
    // Random slight rotation for staggered effect
    private var rotation: Double {
        let rotations: [Double] = [-5, -3, -1, 0, 1, 3, 5]
        return rotations[index % rotations.count]
    }
    
    // Variable card dimensions as per design
    private var cardWidth: CGFloat {
        let widths: [CGFloat] = [150, 170, 160, 180, 200]
        return widths[index % widths.count]
    }
    
    private var cardHeight: CGFloat {
        let heights: [CGFloat] = [120, 140, 130, 150, 160]
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
        VStack(alignment: .leading, spacing: 8) {
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
                        .scaleEffect(isPlaying ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isPlaying)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .frame(width: cardWidth, height: cardHeight)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .rotationEffect(.degrees(rotation))
        .onLongPressGesture {
            showContextMenu()
        }
    }
    
    private func showContextMenu() {
        // Haptic feedback for long press
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // TODO: Implement context menu (Play, Share, Delete, Edit Title)
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
        viewModel: VoiceNotesViewModel()
    )
    .padding()
} 