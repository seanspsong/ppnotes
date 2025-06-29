//
//  PPNotesApp.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI

@main
struct PPNotesApp: App {
    @State private var showLanguageOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkForLanguageOnboarding()
                }
                .fullScreenCover(isPresented: $showLanguageOnboarding) {
                    LanguageSelectionView(showLanguageSelection: $showLanguageOnboarding, isOnboarding: true)
                }
        }
    }
    
    private func checkForLanguageOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HasCompletedLanguageOnboarding")
        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showLanguageOnboarding = true
            }
        }
    }
}
