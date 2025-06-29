//
//  LanguageSelectionView.swift
//  PPNotes
//
//  Created by Sean Song on 1/2/25.
//

import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: SupportedLanguage = .english
    @Binding var showLanguageSelection: Bool
    let isOnboarding: Bool
    
    init(showLanguageSelection: Binding<Bool>, isOnboarding: Bool = false) {
        self._showLanguageSelection = showLanguageSelection
        self.isOnboarding = isOnboarding
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 6) {
                    if isOnboarding {
                        // Onboarding header
                        VStack(spacing: 4) {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.linearGradient(
                                    colors: [.blue, .indigo], 
                                    startPoint: .topLeading, 
                                    endPoint: .bottomTrailing
                                ))
                            
                            VStack(spacing: 2) {
                                Text("Choose Your Language")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                
                                Text("Select your preferred language for voice transcription")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    
                    // Language selection grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ], spacing: 6) {
                        ForEach(SupportedLanguage.allCases, id: \.self) { language in
                            LanguageCard(
                                language: language,
                                isSelected: selectedLanguage == language
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedLanguage = language
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // Action buttons
                    VStack(spacing: 10) {
                        Button(action: saveLanguageSelection) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text(isOnboarding ? "Get Started" : "Save Language")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        if !isOnboarding {
                            Button("Cancel") {
                                showLanguageSelection = false
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 500)
                .padding(.top, 20)
            }
            .navigationTitle(isOnboarding ? "" : "Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showLanguageSelection = false
                        }
                    }
                }
            }
        }
        .onAppear {
            loadCurrentLanguage()
        }
    }
    
    private func loadCurrentLanguage() {
        if let languageCode = UserDefaults.standard.string(forKey: "PreferredTranscriptionLanguage"),
           let supportedLanguage = SupportedLanguage.allCases.first(where: { $0.localeIdentifier == languageCode }) {
            selectedLanguage = supportedLanguage
        } else {
            // Default to English or device language if supported
            let deviceLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
            selectedLanguage = SupportedLanguage.allCases.first(where: { 
                $0.localeIdentifier.hasPrefix(deviceLanguageCode) 
            }) ?? .english
        }
    }
    
    private func saveLanguageSelection() {
        UserDefaults.standard.set(selectedLanguage.localeIdentifier, forKey: "PreferredTranscriptionLanguage")
        UserDefaults.standard.set(true, forKey: "HasCompletedLanguageOnboarding")
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showLanguageSelection = false
        }
    }
}

struct LanguageCard: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Flag/Icon
                Text(language.flag)
                    .font(.system(size: 24))
                
                VStack(spacing: 2) {
                    Text(language.displayName)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(language.nativeName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supported Languages

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en-US"
    case japanese = "ja-JP"
    case chinese = "zh-CN"
    case italian = "it-IT"
    case german = "de-DE"
    case french = "fr-FR"
    case spanish = "es-ES"
    
    var id: String { rawValue }
    
    var localeIdentifier: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "Japanese"
        case .chinese: return "Chinese"
        case .italian: return "Italian"
        case .german: return "German"
        case .french: return "French"
        case .spanish: return "Spanish"
        }
    }
    
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .italian: return "Italiano"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .italian: return "🇮🇹"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        }
    }
}

#Preview {
    LanguageSelectionView(showLanguageSelection: .constant(true), isOnboarding: true)
} 