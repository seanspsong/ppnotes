import Foundation
import EventKit
import SwiftUI
import Combine

@MainActor
class EventKitService: ObservableObject {
    private let eventStore = EKEventStore()
    
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    
    init() {
        updateAuthorizationStatus()
    }
    
    private func updateAuthorizationStatus() {
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    // Helper function to open Settings when permissions are needed
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        }
    }
    
    // MARK: - Authorization
    func requestReminderAccess() async -> Bool {
        // Check current status first
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        print("🔍 [EventKit] Current reminder status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .fullAccess:
            print("✅ [EventKit] Reminder access already granted")
            return true
        case .denied, .restricted:
            print("❌ [EventKit] Reminder access denied/restricted - user needs to enable in Settings")
            return false
        case .notDetermined, .writeOnly:
            break
        case .authorized:
            // Try to get full access
            break
        @unknown default:
            break
        }
        
        do {
            print("🔑 [EventKit] Requesting reminder access...")
            let granted = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            }
            print(granted ? "✅ [EventKit] Reminder access granted" : "❌ [EventKit] Reminder access denied")
            return granted
        } catch {
            print("❌ [EventKit] Failed to request reminder access: \(error)")
            return false
        }
    }
    
    func requestCalendarAccess() async -> Bool {
        // Check current status first
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        print("🔍 [EventKit] Current calendar status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .fullAccess:
            print("✅ [EventKit] Calendar access already granted")
            return true
        case .denied, .restricted:
            print("❌ [EventKit] Calendar access denied/restricted - user needs to enable in Settings")
            return false
        case .notDetermined, .writeOnly:
            break
        case .authorized:
            // Try to get full access
            break
        @unknown default:
            break
        }
        
        do {
            print("🔑 [EventKit] Requesting calendar access...")
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            print(granted ? "✅ [EventKit] Calendar access granted" : "❌ [EventKit] Calendar access denied")
            return granted
        } catch {
            print("❌ [EventKit] Failed to request calendar access: \(error)")
            return false
        }
    }
    
    // MARK: - Reminder Operations
    func addTodoToReminders(_ todo: TodoSuggestion) async throws {
        // Check authorization
        if reminderAuthorizationStatus != .fullAccess {
            let granted = await requestReminderAccess()
            if !granted {
                throw EventKitError.accessDenied
            }
        }
        
        // Use default reminder list
        guard let defaultReminderList = eventStore.defaultCalendarForNewReminders() else {
            throw EventKitError.noSourceAvailable
        }
        
        // Create reminder with final exclamation mark cleanup
        let reminder = EKReminder(eventStore: eventStore)
        let finalCleanTitle = todo.title
            .components(separatedBy: CharacterSet(charactersIn: "!"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 [EventKit] Creating reminder - original: '\(todo.title)' → final: '\(finalCleanTitle)'")
        reminder.title = finalCleanTitle
        reminder.notes = createReminderNotes(for: todo)
        reminder.calendar = defaultReminderList
        
        // Temporarily disable priority to avoid iOS adding exclamation marks
        reminder.priority = 0 // No priority
        print("🔍 [EventKit] Setting reminder priority to 0 (none) to avoid exclamation marks")
        
        // Save reminder
        try eventStore.save(reminder, commit: true)
        print("✅ [EventKit] Successfully added reminder to default list: \(todo.title)")
    }
    

    
    private func createReminderNotes(for todo: TodoSuggestion) -> String {
        var notes = ""
        
        if let todoNotes = todo.notes {
            notes += todoNotes + "\n\n"
        }
        
        notes += "From voice note: \"\(todo.extractedText)\""
        notes += "\n\nCreated by PPNotes"
        
        return notes
    }
    
    private func mapPriorityToEKPriority(_ priority: Int) -> Int {
        // Map 1-9 priority to EKReminder priority (1=high, 5=medium, 9=low)
        switch priority {
        case 1...3: return 1 // High
        case 4...6: return 5 // Medium
        case 7...9: return 9 // Low
        default: return 5 // Medium
        }
    }
    
    // MARK: - Calendar Operations
    func addEventToCalendar(_ event: CalendarSuggestion) async throws {
        // Check authorization
        if calendarAuthorizationStatus != .fullAccess {
            let granted = await requestCalendarAccess()
            if !granted {
                throw EventKitError.accessDenied
            }
        }
        
        // Get or create PPNotes calendar
        let calendar = try await getOrCreatePPNotesCalendar()
        
        // Create event
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.notes = createEventNotes(for: event)
        ekEvent.calendar = calendar
        
        // Set dates
        if let suggestedDate = event.suggestedDate {
            ekEvent.startDate = suggestedDate
            let duration = event.duration ?? 3600 // Default 1 hour
            ekEvent.endDate = suggestedDate.addingTimeInterval(duration)
        } else {
            // Default to next hour, 1 hour duration
            let now = Date()
            let nextHour = Calendar.current.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
            ekEvent.startDate = nextHour
            ekEvent.endDate = nextHour.addingTimeInterval(3600)
        }
        
        // Save event
        try eventStore.save(ekEvent, span: .thisEvent, commit: true)
        print("Successfully added calendar event: \(event.title)")
    }
    
    private func getOrCreatePPNotesCalendar() async throws -> EKCalendar {
        // Check if PPNotes calendar already exists
        let calendars = eventStore.calendars(for: .event)
        
        if let existingCalendar = calendars.first(where: { $0.title == "PPNotes" }) {
            return existingCalendar
        }
        
        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "PPNotes"
        newCalendar.cgColor = UIColor.systemPurple.cgColor
        
        // Set source (use default source for events)
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = defaultSource
        } else {
            // Fallback to first available source
            let sources = eventStore.sources.filter { $0.sourceType == .local || $0.sourceType == .calDAV }
            if let source = sources.first {
                newCalendar.source = source
            } else {
                throw EventKitError.noSourceAvailable
            }
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
    
    private func createEventNotes(for event: CalendarSuggestion) -> String {
        var notes = ""
        
        if let eventNotes = event.notes {
            notes += eventNotes + "\n\n"
        }
        
        notes += "From voice note: \"\(event.extractedText)\""
        notes += "\n\nCreated by PPNotes"
        
        return notes
    }
}

// MARK: - Error Types
enum EventKitError: LocalizedError {
    case accessDenied
    case noSourceAvailable
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access required. Go to Settings app, search for 'PPNotes', then enable Calendar access."
        case .noSourceAvailable:
            return "No calendar source available for saving."
        case .saveFailed:
            return "Failed to save to Calendar/Reminders."
        }
    }
} 