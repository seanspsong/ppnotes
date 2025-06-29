//
//  AIChatView.swift
//  PPNotes
//
//  Created by Sean Song on 1/25/25.
//

import SwiftUI
import FoundationModels

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct AIChatView: View {
    let voiceNote: VoiceNote
    @State private var messages: [ChatMessage] = []
    @State private var currentMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var session: LanguageModelSession? = nil
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat with AI")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("About: \(voiceNote.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(messages.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            Divider()
            
            // Transcription section (collapsible)
            if !voiceNote.transcription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Voice Note Transcription")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: insertTranscription) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Insert")
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    Text(voiceNote.transcription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                        )
                        .lineLimit(3)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                Divider()
            }
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "lightbulb")
                                    .font(.system(size: 50))
                                    .foregroundColor(.accentColor)
                                Text("Chat about your voice note")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Text("Ask questions, get summaries, or discuss the content")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        } else {
                            ForEach(messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isLoading) { _, loading in
                    if loading {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            VStack(spacing: 8) {
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Dismiss") {
                            errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    TextField("Ask about your voice note...", text: $currentMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                        .disabled(isLoading)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                            .clipShape(Circle())
                    }
                    .disabled(currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemGray6))
        }
        .onAppear {
            initializeSession()
        }
    }
    
    private func initializeSession() {
        session = LanguageModelSession(
            instructions: """
            You are a helpful AI assistant specialized in discussing voice notes and transcriptions. 
            The user has recorded a voice note with this content: "\(voiceNote.transcription)"
            
            Help them understand, summarize, analyze, or discuss their voice note content. 
            Be concise but helpful in your responses.
            """
        )
        errorMessage = nil
    }
    
    private func insertTranscription() {
        if currentMessage.isEmpty {
            currentMessage = voiceNote.transcription
        } else {
            currentMessage += "\n\n" + voiceNote.transcription
        }
    }
    
    private func sendMessage() {
        let messageText = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, let session = session else { return }
        
        // Add user message
        let userMessage = ChatMessage(content: messageText, isUser: true, timestamp: Date())
        messages.append(userMessage)
        
        // Clear input
        currentMessage = ""
        isLoading = true
        errorMessage = nil
        
        // Get AI response
        Task {
            do {
                let response = try await session.respond(to: messageText)
                
                await MainActor.run {
                    let responseText = response.content
                    let aiMessage = ChatMessage(content: responseText, isUser: false, timestamp: Date())
                    messages.append(aiMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "AI response failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack {
                    if !message.isUser {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            message.isUser
                                ? Color.accentColor
                                : Color(.systemGray5)
                        )
                        .foregroundColor(
                            message.isUser
                                ? .white
                                : .primary
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    message.isUser
                                        ? Color.clear
                                        : Color(.separator),
                                    lineWidth: 0.5
                                )
                        )
                    
                    if message.isUser {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 300, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

#Preview {
    AIChatView(voiceNote: VoiceNote(
        title: "Meeting Notes",
        audioFileName: "test.m4a",
        duration: 125.0,
        timestamp: Date(),
        transcription: "This is a sample transcription of a voice note. It contains important meeting details and action items that we discussed during our team call."
    ))
} 