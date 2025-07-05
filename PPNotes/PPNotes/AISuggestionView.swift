import SwiftUI

struct AISuggestionView: View {
    let voiceNote: VoiceNote
    @StateObject private var aiSuggestionService = AISuggestionService()
    @StateObject private var eventKitService = EventKitService()
    @State private var hasAnalyzed = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                
                Text("AI Suggestions")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if aiSuggestionService.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if aiSuggestionService.isAnalyzing {
                AnalyzingView()
            } else if !hasAnalyzed {
                EmptyStateView {
                    Task {
                        await aiSuggestionService.analyzeSuggestions(for: voiceNote.transcription)
                        hasAnalyzed = true
                    }
                }
            } else if aiSuggestionService.todos.isEmpty && aiSuggestionService.calendarItems.isEmpty {
                NoSuggestionsView()
            } else {
                SuggestionsContentView(
                    aiSuggestionService: aiSuggestionService,
                    eventKitService: eventKitService,
                    onError: { message in
                        permissionAlertMessage = message
                        showingPermissionAlert = true
                    }
                )
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
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

struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                
                Text("Analyzing transcription...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Looking for todos and calendar items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct EmptyStateView: View {
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.7))
            
            Text("Get AI suggestions for todos and calendar items")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAnalyze) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Analyze")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct NoSuggestionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
            Text("No actionable items found")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("This note doesn't contain any todos or calendar items")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct SuggestionsContentView: View {
    @ObservedObject var aiSuggestionService: AISuggestionService
    @ObservedObject var eventKitService: EventKitService
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Todo suggestions
            if !aiSuggestionService.todos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checklist")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        
                        Text("Todo Items")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(aiSuggestionService.todos.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    
                    ForEach(aiSuggestionService.todos) { todo in
                        TodoSuggestionCard(
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        
                        Text("Calendar Events")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(aiSuggestionService.calendarItems.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    
                    ForEach(aiSuggestionService.calendarItems) { event in
                        CalendarSuggestionCard(
                            event: event,
                            eventKitService: eventKitService,
                            onAdded: {
                                aiSuggestionService.markCalendarItemAsAdded(event)
                            },
                            onError: onError
                        )
                    }
                }
            }
        }
    }
}

struct TodoSuggestionCard: View {
    let todo: TodoSuggestion
    let eventKitService: EventKitService
    let onAdded: () -> Void
    let onError: (String) -> Void
    @State private var isAdding = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let notes = todo.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Priority indicator
                if let priority = todo.priority {
                    PriorityIndicator(priority: priority)
                }
            }
            
            // Original text
            Text("\"\(todo.extractedText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Add button
            HStack {
                Spacer()
                
                if todo.isAdded {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.caption)
                        Text("Added")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                } else {
                    Button(action: {
                        addTodoToReminders()
                    }) {
                        HStack {
                            if isAdding {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                            Text("Add to Reminders")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(isAdding)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func addTodoToReminders() {
        guard !isAdding else { return }
        
        isAdding = true
        
        Task {
            do {
                try await eventKitService.addTodoToReminders(todo)
                await MainActor.run {
                    onAdded()
                    isAdding = false
                }
            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                    isAdding = false
                }
            }
        }
    }
}

struct CalendarSuggestionCard: View {
    let event: CalendarSuggestion
    let eventKitService: EventKitService
    let onAdded: () -> Void
    let onError: (String) -> Void
    @State private var isAdding = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let notes = event.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Date/time info
                if let date = event.suggestedDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Original text
            Text("\"\(event.extractedText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Add button
            HStack {
                Spacer()
                
                if event.isAdded {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.caption)
                        Text("Added")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                } else {
                    Button(action: {
                        addEventToCalendar()
                    }) {
                        HStack {
                            if isAdding {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                            Text("Add to Calendar")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(isAdding)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func addEventToCalendar() {
        guard !isAdding else { return }
        
        isAdding = true
        
        Task {
            do {
                try await eventKitService.addEventToCalendar(event)
                await MainActor.run {
                    onAdded()
                    isAdding = false
                }
            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                    isAdding = false
                }
            }
        }
    }
}

struct PriorityIndicator: View {
    let priority: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: priorityIcon)
                .font(.caption)
                .foregroundColor(priorityColor)
            
            Text(priorityText)
                .font(.caption2)
                .foregroundColor(priorityColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priorityColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var priorityIcon: String {
        switch priority {
        case 1...3: return "exclamationmark.triangle.fill"
        case 4...6: return "circle.fill"
        case 7...9: return "minus.circle.fill"
        default: return "circle.fill"
        }
    }
    
    private var priorityColor: Color {
        switch priority {
        case 1...3: return .red
        case 4...6: return .orange
        case 7...9: return .blue
        default: return .gray
        }
    }
    
    private var priorityText: String {
        switch priority {
        case 1...3: return "HIGH"
        case 4...6: return "MED"
        case 7...9: return "LOW"
        default: return "MED"
        }
    }
}

#Preview {
    AISuggestionView(
        voiceNote: VoiceNote(
            title: "Meeting Notes",
            audioFileName: "voice_note_123.m4a",
            duration: 125.0,
            timestamp: Date(),
            transcription: "I need to call John tomorrow at 3 PM to discuss the project. Also, don't forget to submit the report by Friday and schedule a team meeting for next week."
        )
    )
    .padding()
} 