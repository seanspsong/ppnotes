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
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    
    // Determine if we're on iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Check if sidebar is visible
    private var isSidebarVisible: Bool {
        columnVisibility != .detailOnly
    }
    
    var body: some View {
        Group {
            if isIPad {
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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            NavigationStack {
                iPadSidebar
            }
        } detail: {
            // Main content area
            NavigationStack {
                iPadMainContent
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
                                            ProcessingCard(isRecording: viewModel.isRecording, screenWidth: geometry.size.width)
                                                .transition(.scale.combined(with: .opacity))
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    
                                    // Voice Notes Grid
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                                        ForEach(Array(viewModel.voiceNotes.enumerated()), id: \.element.id) { index, voiceNote in
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
        .navigationBarTitleDisplayMode(.inline)
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
        .navigationTitle("PPnotes")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // iPad Main Grid
    private func iPadMainGrid(geometry: GeometryProxy) -> some View {
        ScrollView {
            if viewModel.voiceNotes.isEmpty && !viewModel.isAddingNewNote {
                emptyStateView
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height - 100)
            } else {
                VStack(spacing: 32) {
                    // Recording/Processing card
                    if viewModel.isAddingNewNote {
                        HStack {
                            ProcessingCard(isRecording: viewModel.isRecording, screenWidth: geometry.size.width)
                                .scaleEffect(0.95)
                                .rotationEffect(.degrees(-2))
                                .shadow(
                                    color: Color.black.opacity(0.2),
                                    radius: 12,
                                    x: -2,
                                    y: 4
                                )
                                .transition(.scale.combined(with: .opacity))
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Voice Notes Grid - Beautiful Dynamic Layout for iPad
                    let voiceNotes = viewModel.voiceNotes
                    let isHorizontal = geometry.size.width > geometry.size.height
                    
                    // Determine grid columns based on orientation and sidebar
                    let columnCount: Int = {
                        if isHorizontal {
                            return isSidebarVisible ? 3 : 4  // Horizontal: 3 with sidebar, 4 without
                        } else {
                            return isSidebarVisible ? 2 : 3  // Vertical: 2 with sidebar, 3 without
                        }
                    }()
                    
                    // Create beautiful staggered grid with random transforms
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 120, maximum: 200), spacing: 24), count: columnCount),
                        spacing: 32
                    ) {
                        ForEach(Array(voiceNotes.enumerated()), id: \.element.id) { index, voiceNote in
                            VoiceNoteCard(
                                voiceNote: voiceNote,
                                index: index,
                                isCurrentlyRecording: false,
                                screenWidth: geometry.size.width,
                                viewModel: viewModel
                            )
                            .id(voiceNote.id)
                            .scaleEffect(randomScale(for: index))
                            .rotationEffect(.degrees(randomRotation(for: index)))
                            .offset(x: randomOffset(for: index), y: randomOffset(for: index, isY: true))
                            .shadow(
                                color: Color.black.opacity(0.15),
                                radius: 10,
                                x: randomShadowX(for: index),
                                y: randomShadowY(for: index)
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0.2), value: voiceNotes.count)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer() // Push content to top
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
        VStack(spacing: 32) {
            Spacer()
            
            // Beautiful empty state illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.1),
                                Color.accentColor.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(1.2)
                    .blur(radius: 20)
                
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.8),
                                Color.accentColor.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(-5))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            
            VStack(spacing: 16) {
                Text("No Voice Notes Yet")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.primary,
                                Color.primary.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Press and hold the microphone button to record your first voice note and start your audio journal")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 60)
            }
            
            Spacer()
        }
        .scaleEffect(0.9)
        .rotationEffect(.degrees(1))
    }
    
    // MARK: - Beautiful Card Transform Functions
    
    /// Generate consistent random scale for each card based on index
    private func randomScale(for index: Int) -> CGFloat {
        let seed = abs(index.hashValue)
        let randomValue = Double((seed % 100)) / 100.0
        return CGFloat(0.85 + randomValue * 0.3) // Scale between 0.85 and 1.15
    }
    
    /// Generate consistent random rotation for each card based on index
    private func randomRotation(for index: Int) -> Double {
        let seed = abs((index * 17).hashValue)
        let randomValue = Double((seed % 100)) / 100.0
        return (randomValue - 0.5) * 12 // Rotation between -6 and +6 degrees
    }
    
    /// Generate consistent random offset for each card based on index
    private func randomOffset(for index: Int, isY: Bool = false) -> CGFloat {
        let seed = abs((index * (isY ? 23 : 19)).hashValue)
        let randomValue = Double((seed % 100)) / 100.0
        return CGFloat((randomValue - 0.5) * 16) // Offset between -8 and +8 points
    }
    
    /// Generate consistent random shadow X offset
    private func randomShadowX(for index: Int) -> CGFloat {
        let seed = abs((index * 31).hashValue)
        let randomValue = Double((seed % 100)) / 100.0
        return CGFloat((randomValue - 0.5) * 6) // Shadow X between -3 and +3
    }
    
    /// Generate consistent random shadow Y offset
    private func randomShadowY(for index: Int) -> CGFloat {
        let seed = abs((index * 37).hashValue)
        let randomValue = Double((seed % 100)) / 100.0
        return CGFloat(2 + randomValue * 4) // Shadow Y between 2 and 6
    }
}

// Processing Card shown while recording or creating new voice note
struct ProcessingCard: View {
    let isRecording: Bool
    let screenWidth: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        let cardWidth = screenWidth * 0.20
        
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
            .padding(20)
            .frame(width: cardWidth, height: 160)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        isRecording ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1),
                        Color(.secondarySystemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                (isRecording ? Color.red : Color.accentColor).opacity(0.6),
                                (isRecording ? Color.red : Color.accentColor).opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    ContentView()
}
