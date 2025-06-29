//
//  VoiceNoteDetailView.swift
//  PPNotes
//
//  Created by Sean Song on 1/25/25.
//

import SwiftUI

struct VoiceNoteDetailView: View {
    let voiceNote: VoiceNote
    @ObservedObject var viewModel: VoiceNotesViewModel
    
    private var isPlaying: Bool {
        viewModel.currentlyPlayingId == voiceNote.id
    }
    
    private var isPaused: Bool {
        viewModel.isNotePaused(voiceNote.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with date and time
                VStack(alignment: .leading, spacing: 8) {
                    Text(voiceNote.displayDate)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(voiceNote.formattedTimestamp)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Title section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Title")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(voiceNote.title)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
                
                // Audio playback section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        // Play/Pause button
                        Button(action: {
                            viewModel.playVoiceNote(voiceNote)
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.accentColor)
                                .scaleEffect(isPlaying ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isPlaying)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Duration and progress
                            HStack {
                                Text("Duration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(voiceNote.formattedDuration)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            
                            if isPlaying {
                                HStack {
                                    Text("Progress")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(viewModel.playbackProgress * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            
                            // Progress bar
                            ProgressView(value: isPlaying ? viewModel.playbackProgress : 0.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                .scaleEffect(y: 1.5)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Transcription section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcription")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if voiceNote.transcription.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text("No transcription available")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    } else {
                        Text(voiceNote.transcription)
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
                
                // Metadata section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 0) {
                        // Created date
                        HStack {
                            Text("Created")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(voiceNote.formattedDate) at \(voiceNote.formattedTimestamp)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // File info
                        HStack {
                            Text("Audio File")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(voiceNote.audioFileName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Voice Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    viewModel.selectedNoteForDetail = nil
                }
                .fontWeight(.medium)
            }
        }
    }
}

#Preview {
    NavigationView {
        VoiceNoteDetailView(
            voiceNote: VoiceNote(
                title: "Meeting Notes",
                audioFileName: "voice_note_123.m4a",
                duration: 125.0,
                timestamp: Date(),
                transcription: "This is a sample transcription of a voice note. It contains multiple sentences and shows how the text would be displayed in the detail view. The transcription can be quite long and will wrap to multiple lines as needed."
            ),
            viewModel: VoiceNotesViewModel()
        )
    }
} 