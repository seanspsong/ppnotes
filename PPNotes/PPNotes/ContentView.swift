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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // Determine if we're on iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Determine if we should use compact layout
    private var shouldUseCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    var body: some View {
        Group {
            if isIPad && !shouldUseCompactLayout {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .preferredColorScheme(nil) // Adaptive to system
        .onAppear {
            loadCurrentLanguageFlag()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadCurrentLanguageFlag()
        }
    }
    
    // iPad Layout - Split View Design
    private var iPadLayout: some View {
        NavigationSplitView {
            // Sidebar
            iPadSidebar
        } detail: {
            // Main content area
            iPadMainContent
        }
        .overlay(
            // Floating recording button at center bottom
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    if viewModel.isRecording {
                        Text(viewModel.formattedRemainingTime)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.isWarningTime ? .red : .primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    RecordingButton(
                        viewModel: viewModel,
                        scaleEffect: 1.0,
                        showTimer: false,
                        showLabel: true
                    )
                }
                .padding(.bottom, 50)
            }
        )
    }
    
    // iPhone Layout - Original Design
    private var iPhoneLayout: some View {
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
                                        AdaptiveGrid(
                                            items: viewModel.voiceNotes,
                                            spacing: 16,
                                            screenWidth: geometry.size.width
                                        ) { voiceNote, index in
                                            VoiceNoteCard(
                                                voiceNote: voiceNote, 
                                                index: index,
                                                isCurrentlyRecording: false,
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
                                    .frame(height: calculateGridHeight(for: viewModel.voiceNotes.count, screenWidth: geometry.size.width))
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
    
    // iPad Sidebar
    private var iPadSidebar: some View {
        VStack(spacing: 0) {
            // Fixed header (just app name)
            HStack {
                Text("PPnotes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Quick stats
                    if !viewModel.voiceNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Voice Notes")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(viewModel.voiceNotes.count)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Total Duration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(totalDuration)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Notes list
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.voiceNotes) { note in
                            iPadSidebarNoteRow(note: note)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }
                .padding(.top, 8)
            }
            

        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarHidden(true)
    }
    
    // iPad Main Content
    private var iPadMainContent: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if let selectedNote = viewModel.selectedNoteForDetail {
                    // Show detail view
                    iPadDetailView(note: selectedNote, geometry: geometry)
                } else {
                    // Show main grid
                    iPadMainGrid(geometry: geometry)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isDeleteMode {
                    Button("Done") {
                        viewModel.exitDeleteMode()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                } else {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // iPad Main Grid
    private func iPadMainGrid(geometry: GeometryProxy) -> some View {
        ScrollView {
            if viewModel.voiceNotes.isEmpty && !viewModel.isAddingNewNote {
                emptyStateView
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height - 100)
            } else {
                LazyVStack(spacing: 32) {
                    // Recording/Processing card
                    if viewModel.isAddingNewNote {
                        HStack {
                            ProcessingCard(isRecording: viewModel.isRecording)
                                .transition(.scale.combined(with: .opacity))
                            Spacer()
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Adaptive grid
                    AdaptiveGrid(
                        items: viewModel.voiceNotes,
                        spacing: 28,
                        screenWidth: geometry.size.width
                    ) { voiceNote, index in
                        VoiceNoteCard(
                            voiceNote: voiceNote,
                            index: index,
                            isCurrentlyRecording: false,
                            screenWidth: geometry.size.width,
                            viewModel: viewModel
                        )
                        .id(voiceNote.id)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                    .frame(height: calculateGridHeight(for: viewModel.voiceNotes.count, screenWidth: geometry.size.width))
                    .padding(.horizontal, 32)
                }
                .padding(.top, 28)
                .padding(.bottom, 60)
            }
        }
        .refreshable {
            // Pull to refresh functionality
        }
    }
    
    // iPad Detail View
    private func iPadDetailView(note: VoiceNote, geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left side - Note content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        viewModel.selectedNoteForDetail = nil
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Share functionality
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Note content
                ScrollView {
                    VoiceNoteDetailContent(voiceNote: note, viewModel: viewModel)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: geometry.size.width * 0.6)
            .background(Color(.systemBackground))
            
            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1)
            
            // Right side - AI Suggestions
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("AI Suggestions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                ScrollView {
                    iPadAISuggestionView(voiceNote: note)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: geometry.size.width * 0.4)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // iPad Sidebar Note Row
    private func iPadSidebarNoteRow(note: VoiceNote) -> some View {
        Button(action: {
            viewModel.selectedNoteForDetail = note
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if viewModel.selectedNoteForDetail?.id == note.id {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text(note.displayDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !note.transcription.isEmpty {
                    Text(note.transcription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedNoteForDetail?.id == note.id ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Calculate total duration
    private var totalDuration: String {
        let total = viewModel.voiceNotes.reduce(0) { $0 + $1.duration }
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    // Calculate grid height based on number of items and screen width
    private func calculateGridHeight(for itemCount: Int, screenWidth: CGFloat) -> CGFloat {
        let columns = columnsForWidth(screenWidth)
        let rows = ceil(Double(itemCount) / Double(columns))
        return CGFloat(rows) * 250 // Approximate card height
    }
    
    // Calculate columns based on screen width
    private func columnsForWidth(_ width: CGFloat) -> Int {
        if width < 600 {
            return 2
        } else if width < 900 {
            return 3
        } else if width < 1200 {
            return 4
        } else {
            return 5
        }
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
        .padding(16)
        .frame(width: 180, height: 140)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
