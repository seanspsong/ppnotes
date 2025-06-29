//
//  SettingsView.swift
//  PPNotes
//
//  Created by Sean Song on 1/2/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showLanguageSelection = false
    @State private var currentLanguage: SupportedLanguage = .english
    
    var body: some View {
        NavigationView {
            List {
                // Language Section
                Section {
                    Button(action: {
                        showLanguageSelection = true
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Language")
                                    .foregroundColor(.primary)
                                
                                Text(currentLanguage.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Text(currentLanguage.flag)
                                    .font(.title3)
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Transcription")
                } footer: {
                    Text("Choose your preferred language for voice note transcription. This affects the accuracy of speech-to-text conversion.")
                }
                
                // About Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text("Version")
                        
                        Spacer()
                        
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text("Developer")
                        
                        Spacer()
                        
                        Text("Sean Song")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
                
                // Privacy Section
                Section {
                    HStack {
                        Image(systemName: "mic.circle")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice Processing")
                                .foregroundColor(.primary)
                            
                            Text("All transcription happens on-device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("PPNotes uses Apple's on-device speech recognition. Your voice recordings and transcriptions never leave your device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionView(showLanguageSelection: $showLanguageSelection, isOnboarding: false)
        }
        .onAppear {
            loadCurrentLanguage()
        }
    }
    
    private func loadCurrentLanguage() {
        if let languageCode = UserDefaults.standard.string(forKey: "PreferredTranscriptionLanguage"),
           let supportedLanguage = SupportedLanguage.allCases.first(where: { $0.localeIdentifier == languageCode }) {
            currentLanguage = supportedLanguage
        } else {
            // Default to English or device language if supported
            let deviceLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = SupportedLanguage.allCases.first(where: { 
                $0.localeIdentifier.hasPrefix(deviceLanguageCode) 
            }) ?? .english
        }
    }
}

#Preview {
    SettingsView()
} 