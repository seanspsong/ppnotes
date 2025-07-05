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
    @StateObject private var eventKitService = EventKitService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkForLanguageOnboarding()
                }
                .fullScreenCover(isPresented: $showLanguageOnboarding) {
                    LanguageSelectionView(showLanguageSelection: $showLanguageOnboarding, isOnboarding: true)
                }
                .onChange(of: showLanguageOnboarding) { _, isShowing in
                    if !isShowing {
                        // Request calendar permissions after onboarding is complete
                        requestCalendarPermissions()
                    }
                }
        }
    }
    
    private func checkForLanguageOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HasCompletedLanguageOnboarding")
        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showLanguageOnboarding = true
            }
        } else {
            // If onboarding was already completed, request permissions immediately
            requestCalendarPermissions()
        }
    }
    
    private func requestCalendarPermissions() {
        Task {
            print("🔑 [App] Requesting calendar permissions at startup...")
            
            // Request both calendar and reminder permissions
            async let calendarGranted = eventKitService.requestCalendarAccess()
            async let reminderGranted = eventKitService.requestReminderAccess()
            
            let (calendarResult, reminderResult) = await (calendarGranted, reminderGranted)
            
            print("📅 [App] Calendar access: \(calendarResult ? "✅ Granted" : "❌ Denied")")
            print("📝 [App] Reminder access: \(reminderResult ? "✅ Granted" : "❌ Denied")")
        }
    }
}
