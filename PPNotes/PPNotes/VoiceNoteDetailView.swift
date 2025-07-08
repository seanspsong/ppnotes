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
    @Environment(\.dismiss) private var dismiss
    @State private var showingAIChat = false
    
    var body: some View {
        ScrollView {
            VoiceNoteDetailContent(voiceNote: voiceNote, viewModel: viewModel)
        }
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showingAIChat) {
            AIChatView(voiceNote: voiceNote)
        }
    }
}

struct VoiceNoteDetailContent: View {
    let voiceNote: VoiceNote
    @ObservedObject var viewModel: VoiceNotesViewModel
    @State private var showingAIChat = false
    @State private var showingAddTag = false
    @State private var newTag = ""
    
    private var isPlaying: Bool {
        viewModel.currentlyPlayingId == voiceNote.id
    }
    
    private var isPaused: Bool {
        viewModel.isNotePaused(voiceNote.id)
    }
    
    private var predefinedTags: [String] {
        let allTags = ["meeting", "work", "personal", "idea", "reminder", "todo", "call", "note", "important", "project"]
        return allTags.filter { !voiceNote.tags.contains($0) }
    }
    
    var body: some View {
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
            .padding(.horizontal, 20)
            
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
            .padding(.horizontal, 20)
            
            // Tags section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddTag = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Add Tag")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if voiceNote.tags.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tag.slash")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("No tags")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Add tags to organize your voice notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(voiceNote.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                                
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    viewModel.removeTag(from: voiceNote.id, tag: tag)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                }
                
                // Predefined tags section
                if !predefinedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Tags")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(predefinedTags, id: \.self) { tag in
                                Button(action: {
                                    viewModel.addTag(to: voiceNote.id, tag: tag)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                            .font(.caption2)
                                        
                                        Text(tag)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(voiceNote.tags.contains(tag))
                                .opacity(voiceNote.tags.contains(tag) ? 0.5 : 1.0)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .alert("Add Tag", isPresented: $showingAddTag) {
                TextField("Tag name", text: $newTag)
                    .textInputAutocapitalization(.words)
                
                Button("Add") {
                    if !newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.addTag(to: voiceNote.id, tag: newTag.trimmingCharacters(in: .whitespacesAndNewlines))
                        newTag = ""
                    }
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("Cancel", role: .cancel) {
                    newTag = ""
                }
            } message: {
                Text("Enter a tag name to organize your voice notes")
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
            .padding(.horizontal, 20)
            
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
            .padding(.horizontal, 20)
            
            // AI Suggestions section (only show on iPhone)
            if UIDevice.current.userInterfaceIdiom != .pad && !voiceNote.transcription.isEmpty {
                AISuggestionView(voiceNote: voiceNote)
                    .padding(.horizontal, 20)
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
            .padding(.horizontal, 20)
            
            // AI Chat button
            Button(action: {
                showingAIChat = true
            }) {
                HStack {
                    Image(systemName: "ellipsis.bubble")
                        .font(.title3)
                    Text("Chat with AI about this note")
                        .font(.headline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.accentColor)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(voiceNote.transcription.isEmpty)
            .opacity(voiceNote.transcription.isEmpty ? 0.5 : 1.0)
            
            if voiceNote.transcription.isEmpty {
                Text("AI chat is available after transcription completes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            
            // Bottom spacing
            Rectangle()
                .fill(Color.clear)
                .frame(height: 40)
        }
        .padding(.vertical, 20)
        .sheet(isPresented: $showingAIChat) {
            AIChatView(voiceNote: voiceNote)
        }
    }
}

// iPad-specific AI Suggestions View
struct iPadAISuggestionView: View {
    let voiceNote: VoiceNote
    @StateObject private var aiSuggestionService = AISuggestionService()
    @StateObject private var eventKitService = EventKitService()
    @State private var hasAnalyzed = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if aiSuggestionService.isAnalyzing {
                iPadAnalyzingView()
            } else if !hasAnalyzed {
                iPadEmptyStateView {
                    Task {
                        await aiSuggestionService.analyzeSuggestions(for: voiceNote.transcription)
                        hasAnalyzed = true
                    }
                }
            } else if aiSuggestionService.todos.isEmpty && aiSuggestionService.calendarItems.isEmpty {
                iPadNoSuggestionsView()
            } else {
                iPadSuggestionsContentView(
                    aiSuggestionService: aiSuggestionService,
                    eventKitService: eventKitService,
                    onError: { message in
                        permissionAlertMessage = message
                        showingPermissionAlert = true
                    }
                )
            }
        }
        .alert("Calendar Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                eventKitService.openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
        .onAppear {
            if !voiceNote.transcription.isEmpty && !hasAnalyzed {
                Task {
                    await aiSuggestionService.analyzeSuggestions(for: voiceNote.transcription)
                    hasAnalyzed = true
                }
            }
        }
    }
}

// iPad-specific UI components
struct iPadAnalyzingView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                
                Text("Analyzing transcription...")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            
            Text("Looking for todos and calendar items")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct iPadEmptyStateView: View {
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.7))
            
            Text("Get AI suggestions for todos and calendar items")
                .font(.title3)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Button(action: onAnalyze) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Analyze")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct iPadNoSuggestionsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("No actionable items found")
                .font(.title3)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("This note doesn't contain any todos or calendar items")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct iPadSuggestionsContentView: View {
    @ObservedObject var aiSuggestionService: AISuggestionService
    @ObservedObject var eventKitService: EventKitService
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Todo suggestions
            if !aiSuggestionService.todos.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "checklist")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        Text("Todo Items")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(aiSuggestionService.todos.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    
                    ForEach(aiSuggestionService.todos) { todo in
                        iPadTodoSuggestionCard(
                            todo: todo,
                            eventKitService: eventKitService,
                            onAdded: {
                                aiSuggestionService.markTodoAsAdded(todo)
                            },
                            onError: onError
                        )
                    }
                }
            }
            
            // Calendar suggestions
            if !aiSuggestionService.calendarItems.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        Text("Calendar Events")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(aiSuggestionService.calendarItems.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    
                    ForEach(aiSuggestionService.calendarItems) { item in
                        iPadCalendarSuggestionCard(
                            item: item,
                            eventKitService: eventKitService,
                            onAdded: {
                                aiSuggestionService.markCalendarItemAsAdded(item)
                            },
                            onError: onError
                        )
                    }
                }
            }
        }
    }
}

struct iPadTodoSuggestionCard: View {
    let todo: TodoSuggestion
    @ObservedObject var eventKitService: EventKitService
    let onAdded: () -> Void
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let notes = todo.notes {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if todo.isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Button(action: {
                        Task {
                            await addTodoToReminders()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            // Show extracted text
            Text("From: \"\(todo.extractedText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func addTodoToReminders() async {
        do {
            try await eventKitService.addTodoToReminders(todo)
            onAdded()
        } catch {
            onError(error.localizedDescription)
        }
    }
}

struct iPadCalendarSuggestionCard: View {
    let item: CalendarSuggestion
    @ObservedObject var eventKitService: EventKitService
    let onAdded: () -> Void
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let notes = item.notes {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if item.isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Button(action: {
                        Task {
                            await addEventToCalendar()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            // Show date and location if available
            VStack(alignment: .leading, spacing: 4) {
                if let date = item.suggestedDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let location = item.location {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Show extracted text
            Text("From: \"\(item.extractedText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func addEventToCalendar() async {
        do {
            try await eventKitService.addEventToCalendar(item)
            onAdded()
        } catch {
            onError(error.localizedDescription)
        }
    }
}

#Preview {
    VStack {
        VoiceNoteDetailView(
            voiceNote: VoiceNote(
                title: "Test Title",
                audioFileName: "test.m4a",
                duration: 30,
                timestamp: Date(),
                transcription: "Test transcription",
                tags: ["test"]
            ),
            viewModel: VoiceNotesViewModel()
        )
    }
} 