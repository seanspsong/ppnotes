import Foundation
import FoundationModels
import Combine

// MARK: - Data Models
struct TodoSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let notes: String?
    let priority: Int? // 1-9 (1 = highest)
    let extractedText: String // Original text from transcription
    var isAdded: Bool = false
}

struct CalendarSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let notes: String?
    let suggestedDate: Date?
    let duration: TimeInterval? // in seconds
    let location: String? // Location if mentioned in transcription
    let extractedText: String // Original text from transcription
    var isAdded: Bool = false
}

// MARK: - AI Suggestion Service
@MainActor
class AISuggestionService: ObservableObject {
    @Published var todos: [TodoSuggestion] = []
    @Published var calendarItems: [CalendarSuggestion] = []
    @Published var isAnalyzing = false
    @Published var error: String?
    
    private var session: LanguageModelSession?
    
    func analyzeSuggestions(for transcription: String) async {
        guard !transcription.isEmpty else { 
            print("❌ [AI Suggestion] Empty transcription provided")
            return 
        }
        
        print("🎯 [AI Suggestion] Starting unified analysis for transcription: '\(transcription)'")
        isAnalyzing = true
        error = nil
        
        do {
            // Initialize session if needed
            if session == nil {
                session = LanguageModelSession(
                    instructions: "You are a helpful AI assistant specialized in extracting actionable items from voice note transcriptions. You analyze text to categorize items as either calendar events or reminders based on context."
                )
                print("✅ [AI Suggestion] Initialized new LanguageModelSession")
            }
            
            // Run unified analysis that categorizes items appropriately
            let (extractedTodos, extractedCalendar) = await extractCategorizedItems(from: transcription)
            
            todos = extractedTodos
            calendarItems = extractedCalendar
            
            print("📊 [AI Suggestion] Analysis complete: \(extractedTodos.count) reminders, \(extractedCalendar.count) calendar events")
            
        } catch {
            self.error = "Failed to analyze suggestions: \(error.localizedDescription)"
            print("❌ [AI Suggestion] Error: \(error.localizedDescription)")
        }
        
        isAnalyzing = false
    }
    
    private func extractCategorizedItems(from transcription: String) async -> ([TodoSuggestion], [CalendarSuggestion]) {
        let today = Date()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        
        // Calculate key dates for AI reference
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
        
        let prompt = """
        Analyze this voice note transcription and extract actionable items. Categorize each item as either a CALENDAR EVENT or REMINDER based on these rules:
        
        🎯 CRITICAL DECISION LOGIC - FOLLOW EXACTLY:
        
        📅 CREATE CALENDAR EVENT IF ANY ONE OF THESE IS TRUE:
        - Time words: "AM", "PM", "o'clock", "noon", "midnight", "morning", "afternoon", "evening", "tonight"
        - Date words: "tomorrow", "today", "Friday", "Monday", "Tuesday", "Wednesday", "Thursday", "Saturday", "Sunday", "next week", "weekend"
        - Person names: ANY proper name like "Leo", "John", "Sarah", "Dr. Smith", "Tom", etc.
        - Social activities: "play with", "meet with", "dinner with", "lunch with", "call", "visit"
        - Appointments: "appointment", "meeting", "visit Dr.", "dentist"
        - Calendar keyword: "calendar"
        
        📝 CREATE REMINDER ONLY IF ALL OF THESE ARE TRUE:
        - NO time mentioned at all
        - NO date mentioned at all
        - NO other people mentioned at all
        - Personal solo tasks: "buy", "get", "remember", "finish", "complete"
        - OR contains "remind me", "reminder", "don't forget"
        
        🚨 ABSOLUTE RULES - NO EXCEPTIONS:
        1. "play soccer with Leo on tomorrow at 5 PM" → CALENDAR EVENT (has person + date + time)
        2. "I will need to visit Dr. John tomorrow morning 5 AM" → CALENDAR EVENT (has person + date + time)
        3. "Remind me to buy a Mac Apple AirPods Pro" → REMINDER (starts with "remind me", no time/date/people)
        4. ANY activity with ANOTHER PERSON + TIME/DATE → CALENDAR EVENT
        5. ANY activity with just TIME or just DATE → CALENDAR EVENT
        6. When in doubt between calendar and reminder → CHOOSE CALENDAR EVENT
        
        ⚠️ CRITICAL INSTRUCTIONS - FOLLOW EXACTLY:
        1. ALWAYS extract actionable items from every voice note - never return empty results
        2. READ the transcription word by word looking for time, date, and people
        3. If you find ANY time word (AM, PM, morning, etc.) → CALENDAR EVENT
        4. If you find ANY date word (tomorrow, Friday, etc.) → CALENDAR EVENT  
        5. If you find ANY person name (Leo, John, Dr. Smith, etc.) → CALENDAR EVENT
        6. Only create REMINDER if it's purely personal with NO time, NO date, NO people
        7. When analyzing "I will need to play soccer with Leo on tomorrow at 5 PM":
           - "Leo" = person name → CALENDAR EVENT
           - "tomorrow" = date word → CALENDAR EVENT
           - "5 PM" = time word → CALENDAR EVENT
           - This has ALL THREE triggers → DEFINITELY CALENDAR EVENT
        8. Do NOT create both calendar event AND reminder for same item
        9. If uncertain → choose CALENDAR EVENT over REMINDER
        
        FORMAT: Return JSON with this structure:
        {
            "reminders": [
                {
                    "title": "Task title",
                    "notes": "Additional details if any",
                    "priority": 5,
                    "extractedText": "Original text from transcription"
                }
            ],
            "events": [
                {
                    "title": "Event title",
                    "notes": "Additional details if any",
                    "suggestedDate": "2025-01-25T15:30:00",
                    "duration": 3600,
                    "location": "Location if mentioned",
                    "extractedText": "Original text from transcription"
                }
            ]
        }
        
        DATE CALCULATION RULES:
        - TODAY is: \(dateFormatter.string(from: today))
        - TOMORROW is: \(dateFormatter.string(from: tomorrow))
        - NEXT WEEK is: \(dateFormatter.string(from: nextWeek))
        - Convert relative dates to LOCAL time (no Z suffix)
        - "tomorrow" → use \(tomorrow.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))
        - "next week" → use \(nextWeek.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))
        - "today" → use \(today.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))
        
        TIME PARSING RULES:
        - ALWAYS extract and use specific times mentioned in the voice note
        - "10 PM" or "10pm" → set hour to 22 (24-hour format)
        - "3 PM" or "3pm" → set hour to 15
        - "9 AM" or "9am" → set hour to 9
        - "noon" or "12 PM" → set hour to 12
        - "midnight" or "12 AM" → set hour to 0
        - If specific time mentioned, use EXACT time, not defaults
        - Only use defaults if NO time is mentioned: meetings at 10am, calls at 2pm, dinner at 7pm
        
        LOCATION EXTRACTION RULES:
        - Extract location information from voice notes
        - Look for keywords: at, in, on, from, to, meet at, dinner at, office, home, etc.
        - Examples: "meeting at Starbucks", "dinner at Mario's Restaurant", "call from office"
        - Include full address or establishment name if mentioned
        - Use null for location if no location mentioned
        
        EXAMPLES - STUDY THESE CAREFULLY:
        - "Buy groceries" → REMINDER (no time, no date, no people - pure personal task)
        - "Remind me to buy a Mac Apple AirPods Pro" → REMINDER (starts with "remind me", no time/date/people)
        - "I will need to play soccer with Leo on tomorrow at 5 PM" → CALENDAR EVENT (has Leo + tomorrow + 5 PM)
        - "I will need to visit Dr. John tomorrow morning 5 AM" → CALENDAR EVENT (has Dr. John + tomorrow + 5 AM)
        - "Meeting with John tomorrow at 2pm" → CALENDAR EVENT (has John + tomorrow + 2pm)
        - "Visit Dr. John on 10 AM tomorrow morning" → CALENDAR EVENT (has Dr. John + 10 AM + tomorrow)
        - "Doctor appointment Friday" → CALENDAR EVENT (has Friday date)
        - "Call Sarah at 3pm" → CALENDAR EVENT (has Sarah + 3pm)
        - "Play tennis tomorrow" → CALENDAR EVENT (has tomorrow date)
        - "Dinner at Mario's tonight" → CALENDAR EVENT (has tonight time)
        - "Meet Leo for lunch" → CALENDAR EVENT (has Leo person)
        - "Add to calendar: doctor appointment Friday" → CALENDAR EVENT (contains "calendar")
        - "Finish the report" → REMINDER (no time, no date, no people - solo task)
        - "Schedule meeting with team next week" → CALENDAR EVENT (has team + next week)
        - "Pick up prescription tomorrow" → CALENDAR EVENT (has tomorrow date)
        - "Study for exam" → REMINDER (no time, no date, no people - solo task)
        - "Don't forget to buy milk" → REMINDER (starts with "don't forget", no time/date/people)
        
        GENERAL RULES:
        - NEVER use exclamation marks (!, !!, !!!) in titles - they will be removed
        - Use simple, clean language without dramatic emphasis or punctuation
        - Keep titles concise (under 50 characters)
        - Include context in notes if helpful
        - extractedText should be the original phrase/sentence from transcription
        - Priority for reminders: 1-9 (1=highest, 5=normal, 9=lowest)
        - Duration for events in seconds (default 3600 for 1 hour if not specified)
        
        Transcription: "\(transcription)"
        """
        
        do {
            guard let session = session else { return ([], []) }
            print("📝 [AI Unified] Input transcription: '\(transcription)'")
            let response = try await session.respond(to: prompt)
            print("🤖 [AI Unified] Raw response: \(response.content)")
            let result = parseCategorizedResponse(response.content)
            print("📊 [AI Unified] Final result: \(result.0.count) reminders, \(result.1.count) calendar events")
            return result
        } catch {
            print("❌ [AI Unified] Error extracting categorized items: \(error)")
            return ([], [])
        }
    }
    
    private func extractTodos(from transcription: String) async -> [TodoSuggestion] {
        let prompt = """
        Analyze this voice note transcription and extract any tasks, todos, or action items.
        
        Format your response as JSON with this structure:
        {
            "todos": [
                {
                    "title": "Task title",
                    "notes": "Additional details if any",
                    "priority": 5,
                    "extractedText": "Original text from transcription"
                }
            ]
        }
        
        Rules:
        - Extract actionable tasks, todos, and things to do
        - Look for keywords like: need to, should, must, have to, remember to, buy, call, email, etc.
        - Priority: 1-9 (1=highest, 5=normal, 9=lowest)
        - Keep titles concise (under 50 characters)
        - NEVER use exclamation marks (!, !!, !!!) in titles - they will be removed
        - Use simple, clean language without dramatic emphasis or punctuation
        - Include context in notes if helpful
        - extractedText should be the original phrase/sentence from transcription
        
        Examples of what to extract:
        - "Need to buy groceries" → extract as todo
        - "Remember to call mom" → extract as todo
        - "Should finish the report" → extract as todo
        - "Pick up dry cleaning" → extract as todo
        
        Transcription: "\(transcription)"
        """
        
        do {
            guard let session = session else { return [] }
            let response = try await session.respond(to: prompt)
            print("🤖 [AI Todo] Raw response: \(response.content)")
            return parseTodoResponse(response.content)
        } catch {
            print("❌ [AI Todo] Error extracting todos: \(error)")
            return []
        }
    }
    
    private func extractCalendarItems(from transcription: String) async -> [CalendarSuggestion] {
        let today = Date()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        
        // Calculate key dates for AI reference
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
        
        let prompt = """
        Analyze this voice note transcription and extract any events, meetings, appointments, or scheduling requests.
        
        FORMAT: Return JSON with this exact structure:
        {
            "events": [
                {
                    "title": "Event title",
                    "notes": "Additional details if any",
                    "suggestedDate": "2025-01-25T15:30:00",
                    "duration": 3600,
                    "location": "Location if mentioned",
                    "extractedText": "Original text from transcription"
                }
            ]
        }
        
        DATE CALCULATION RULES:
        - TODAY is: \(dateFormatter.string(from: today))
        - TOMORROW is: \(dateFormatter.string(from: tomorrow))
        - NEXT WEEK is: \(dateFormatter.string(from: nextWeek))
        - Convert relative dates to LOCAL time (no Z suffix)
        - "tomorrow" → use \(tomorrow.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))
        - "next week" → use \(nextWeek.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))
        - "today" → use \(today.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))
        
        TIME PARSING RULES:
        - ALWAYS extract and use specific times mentioned in the voice note
        - "10 PM" or "10pm" → set hour to 22 (24-hour format)
        - "3 PM" or "3pm" → set hour to 15
        - "9 AM" or "9am" → set hour to 9
        - "noon" or "12 PM" → set hour to 12
        - "midnight" or "12 AM" → set hour to 0
        - If specific time mentioned, use EXACT time, not defaults
        - Only use defaults if NO time is mentioned: meetings at 10am, calls at 2pm, dinner at 7pm
        
        EXTRACTION RULES:
        - Extract events, meetings, appointments, and scheduling requests
        - Include items even without specific dates/times (use null for suggestedDate)
        - Look for keywords like: schedule, meeting, appointment, call, event, dinner, lunch, etc.
        - Duration in seconds (default 3600 for 1 hour if not specified)
        - NEVER use exclamation marks (!, !!, !!!) in titles - they will be removed
        - Use simple, clean language without dramatic emphasis or punctuation
        - Include context in notes if helpful
        - extractedText should be the original phrase/sentence from transcription
        
        LOCATION EXTRACTION RULES:
        - Extract location information from voice notes
        - Look for keywords: at, in, on, from, to, meet at, dinner at, office, home, etc.
        - Examples: "meeting at Starbucks", "dinner at Mario's Restaurant", "call from office"
        - Include full address or establishment name if mentioned
        - Use null for location if no location mentioned
        
        EXAMPLES:
        - "Schedule meeting with Aaron tomorrow" → suggestedDate: "\(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)?.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? tomorrow.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))", location: null
        - "Call mom tomorrow at 3pm" → suggestedDate: "\(calendar.date(bySettingHour: 15, minute: 0, second: 0, of: tomorrow)?.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? tomorrow.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))", location: null
        - "Tonight's 10 PM write report" → suggestedDate: "\(calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today)?.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? today.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))", location: null
        - "Meeting at Starbucks tomorrow 2pm" → suggestedDate: "\(calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow)?.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? tomorrow.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))", location: "Starbucks"
        - "Dinner with friends at Mario's Restaurant tonight" → suggestedDate: "\(calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)?.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? today.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))", location: "Mario's Restaurant"
        
        Transcription: "\(transcription)"
        """
        
        do {
            guard let session = session else { return [] }
            let response = try await session.respond(to: prompt)
            print("🤖 [AI Calendar] Raw response: \(response.content)")
            return parseCalendarResponse(response.content)
        } catch {
            print("❌ [AI Calendar] Error extracting calendar items: \(error)")
            return []
        }
    }
    
    private func parseTodoResponse(_ response: String) -> [TodoSuggestion] {
        print("🔍 [AI Todo] Parsing response: '\(response)'")
        
        // Strip markdown code block wrapper if present
        let cleanedResponse = response
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "\n```", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🧹 [AI Todo] Cleaned response: '\(cleanedResponse)'")
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("❌ [AI Todo] Failed to convert response to data")
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ [AI Todo] Failed to parse JSON from response")
            return []
        }
        
        print("✅ [AI Todo] Successfully parsed JSON: \(json)")
        
        guard let todosArray = json["todos"] as? [[String: Any]] else {
            print("❌ [AI Todo] Failed to find 'todos' array in JSON")
            return []
        }
        
        let results = todosArray.compactMap { todoDict -> TodoSuggestion? in
            guard let title = todoDict["title"] as? String,
                  let extractedText = todoDict["extractedText"] as? String else {
                print("❌ [AI Todo] Missing required fields in todo item")
                return nil
            }
            
            // Clean up title by removing all exclamation marks and trimming
            let cleanTitle = title
                .components(separatedBy: CharacterSet(charactersIn: "!"))
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🧹 [AI Todo] Title cleanup: '\(title)' → '\(cleanTitle)'")
            
            return TodoSuggestion(
                title: cleanTitle,
                notes: todoDict["notes"] as? String,
                priority: todoDict["priority"] as? Int,
                extractedText: extractedText
            )
        }
        
        print("✅ [AI Todo] Parsed \(results.count) todo items")
        return results
    }
    
    private func parseCalendarResponse(_ response: String) -> [CalendarSuggestion] {
        print("🔍 [AI Calendar] Parsing response: '\(response)'")
        
        // Strip markdown code block wrapper if present
        let cleanedResponse = response
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "\n```", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🧹 [AI Calendar] Cleaned response: '\(cleanedResponse)'")
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("❌ [AI Calendar] Failed to convert response to data")
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ [AI Calendar] Failed to parse JSON from response")
            return []
        }
        
        print("✅ [AI Calendar] Successfully parsed JSON: \(json)")
        
        guard let eventsArray = json["events"] as? [[String: Any]] else {
            print("❌ [AI Calendar] Failed to find 'events' array in JSON")
            return []
        }
        
        // Create date formatter for local time zone
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current // Use local time zone instead of UTC
        
        let results = eventsArray.compactMap { eventDict -> CalendarSuggestion? in
            guard let title = eventDict["title"] as? String,
                  let extractedText = eventDict["extractedText"] as? String else {
                print("❌ [AI Calendar] Missing required fields in calendar item")
                return nil
            }
            
            let suggestedDate: Date?
            if let dateString = eventDict["suggestedDate"] as? String {
                // Try parsing with local time zone first
                suggestedDate = dateFormatter.date(from: dateString) ?? parseRelativeDate(from: dateString, extractedText: extractedText)
                print("📅 [AI Calendar] Date parsing: '\(dateString)' → \(suggestedDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "nil") (local time)")
            } else {
                suggestedDate = parseRelativeDate(from: "", extractedText: extractedText)
                print("📅 [AI Calendar] No date provided, trying to extract from text: '\(extractedText)'")
            }
            
            // Clean up title by removing all exclamation marks and trimming
            let cleanTitle = title
                .components(separatedBy: CharacterSet(charactersIn: "!"))
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🧹 [AI Calendar] Title cleanup: '\(title)' → '\(cleanTitle)'")
            
            return CalendarSuggestion(
                title: cleanTitle,
                notes: eventDict["notes"] as? String,
                suggestedDate: suggestedDate,
                duration: eventDict["duration"] as? TimeInterval,
                location: eventDict["location"] as? String,
                extractedText: extractedText
            )
        }
        
        print("✅ [AI Calendar] Parsed \(results.count) calendar items")
        return results
    }
    
    private func parseCategorizedResponse(_ response: String) -> ([TodoSuggestion], [CalendarSuggestion]) {
        print("🔍 [AI Unified] Parsing response: '\(response)'")
        
        // Strip markdown code block wrapper if present
        let cleanedResponse = response
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "\n```", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🧹 [AI Unified] Cleaned response: '\(cleanedResponse)'")
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("❌ [AI Unified] Failed to convert response to data")
            return ([], [])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ [AI Unified] Failed to parse JSON from response")
            return ([], [])
        }
        
        print("✅ [AI Unified] Successfully parsed JSON: \(json)")
        
        // Parse reminders
        var todos: [TodoSuggestion] = []
        if let remindersArray = json["reminders"] as? [[String: Any]] {
            todos = remindersArray.compactMap { todoDict -> TodoSuggestion? in
                guard let title = todoDict["title"] as? String,
                      let extractedText = todoDict["extractedText"] as? String else {
                    print("❌ [AI Unified] Missing required fields in reminder item")
                    return nil
                }
                
                // Clean up title by removing all exclamation marks and trimming
                let cleanTitle = title
                    .components(separatedBy: CharacterSet(charactersIn: "!"))
                    .joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("🧹 [AI Unified] Reminder title cleanup: '\(title)' → '\(cleanTitle)'")
                
                return TodoSuggestion(
                    title: cleanTitle,
                    notes: todoDict["notes"] as? String,
                    priority: todoDict["priority"] as? Int,
                    extractedText: extractedText
                )
            }
        }
        
        // Parse calendar events
        var calendarItems: [CalendarSuggestion] = []
        if let eventsArray = json["events"] as? [[String: Any]] {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone.current // Use local time zone instead of UTC
            
            calendarItems = eventsArray.compactMap { eventDict -> CalendarSuggestion? in
                guard let title = eventDict["title"] as? String,
                      let extractedText = eventDict["extractedText"] as? String else {
                    print("❌ [AI Unified] Missing required fields in calendar item")
                    return nil
                }
                
                let suggestedDate: Date?
                if let dateString = eventDict["suggestedDate"] as? String {
                    // Try parsing with local time zone first
                    suggestedDate = dateFormatter.date(from: dateString) ?? parseRelativeDate(from: dateString, extractedText: extractedText)
                    print("📅 [AI Unified] Date parsing: '\(dateString)' → \(suggestedDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "nil") (local time)")
                } else {
                    suggestedDate = parseRelativeDate(from: "", extractedText: extractedText)
                    print("📅 [AI Unified] No date provided, trying to extract from text: '\(extractedText)'")
                }
                
                // Clean up title by removing all exclamation marks and trimming
                let cleanTitle = title
                    .components(separatedBy: CharacterSet(charactersIn: "!"))
                    .joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("🧹 [AI Unified] Event title cleanup: '\(title)' → '\(cleanTitle)'")
                
                return CalendarSuggestion(
                    title: cleanTitle,
                    notes: eventDict["notes"] as? String,
                    suggestedDate: suggestedDate,
                    duration: eventDict["duration"] as? TimeInterval,
                    location: eventDict["location"] as? String,
                    extractedText: extractedText
                )
            }
        }
        
        print("✅ [AI Unified] Parsed \(todos.count) reminders and \(calendarItems.count) calendar events")
        return (todos, calendarItems)
    }
    
    private func parseRelativeDate(from dateString: String, extractedText: String) -> Date? {
        let calendar = Calendar.current
        let today = Date()
        
        // Check both the AI-provided date string and the original extracted text
        let textToCheck = (dateString + " " + extractedText).lowercased()
        
        print("🔍 [AI Calendar] Parsing relative date from: '\(textToCheck)'")
        
        // First, determine the base date
        var baseDate: Date = today
        
        if textToCheck.contains("tomorrow") {
            baseDate = calendar.date(byAdding: .day, value: 1, to: today)!
            print("📅 [AI Calendar] Found 'tomorrow' as base date")
        } else if textToCheck.contains("today") || textToCheck.contains("tonight") {
            baseDate = today
            print("📅 [AI Calendar] Found 'today/tonight' as base date")
        } else if textToCheck.contains("next week") {
            baseDate = calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
            print("📅 [AI Calendar] Found 'next week' as base date")
        } else if textToCheck.contains("next friday") || textToCheck.contains("friday") {
            baseDate = getNext(weekday: 6, from: today) // Friday is 6
            print("📅 [AI Calendar] Found 'friday' as base date")
        } else if textToCheck.contains("next monday") || textToCheck.contains("monday") {
            baseDate = getNext(weekday: 2, from: today) // Monday is 2
            print("📅 [AI Calendar] Found 'monday' as base date")
        }
        
        // Now extract specific time if mentioned
        let finalDate = extractTimeFromText(textToCheck, baseDate: baseDate)
        print("📅 [AI Calendar] Final calculated date: \(finalDate?.ISO8601Format() ?? "nil")")
        
        return finalDate
    }
    
    private func extractTimeFromText(_ text: String, baseDate: Date) -> Date? {
        let calendar = Calendar.current
        
        // Look for specific time patterns
        if let timeMatch = extractSpecificTime(from: text) {
            let hour = timeMatch.hour
            let minute = timeMatch.minute
            
            let finalDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
            print("⏰ [AI Calendar] Extracted time \(hour):\(minute) → \(finalDate?.ISO8601Format() ?? "nil")")
            return finalDate
        }
        
        // If no specific time found, use default times based on context
        let defaultTime = getDefaultTimeForContext(text)
        let finalDate = calendar.date(bySettingHour: defaultTime, minute: 0, second: 0, of: baseDate)
        print("⏰ [AI Calendar] Using default time \(defaultTime):00 → \(finalDate?.ISO8601Format() ?? "nil")")
        return finalDate
    }
    
    private func extractSpecificTime(from text: String) -> (hour: Int, minute: Int)? {
        // Common time patterns
        let timePatterns = [
            ("12 am", 0), ("midnight", 0),
            ("1 am", 1), ("2 am", 2), ("3 am", 3), ("4 am", 4), ("5 am", 5), ("6 am", 6),
            ("7 am", 7), ("8 am", 8), ("9 am", 9), ("10 am", 10), ("11 am", 11),
            ("12 pm", 12), ("noon", 12),
            ("1 pm", 13), ("2 pm", 14), ("3 pm", 15), ("4 pm", 16), ("5 pm", 17), ("6 pm", 18),
            ("7 pm", 19), ("8 pm", 20), ("9 pm", 21), ("10 pm", 22), ("11 pm", 23)
        ]
        
        for (pattern, hour) in timePatterns {
            if text.contains(pattern) {
                print("⏰ [AI Calendar] Found time pattern '\(pattern)' → hour \(hour)")
                return (hour: hour, minute: 0)
            }
        }
        
        // Also check for variations like "10pm", "3pm", etc.
        for (pattern, hour) in timePatterns {
            let compactPattern = pattern.replacingOccurrences(of: " ", with: "")
            if text.contains(compactPattern) {
                print("⏰ [AI Calendar] Found compact time pattern '\(compactPattern)' → hour \(hour)")
                return (hour: hour, minute: 0)
            }
        }
        
        return nil
    }
    
    private func getDefaultTimeForContext(_ text: String) -> Int {
        if text.contains("meeting") || text.contains("appointment") {
            return 10 // 10 AM
        } else if text.contains("call") {
            return 14 // 2 PM
        } else if text.contains("dinner") || text.contains("lunch") {
            return 19 // 7 PM for dinner, but this is basic
        } else if text.contains("tonight") {
            return 19 // 7 PM default for evening
        }
        return 10 // Default to 10 AM
    }
    
    private func getNext(weekday: Int, from date: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.weekday], from: date).weekday!
        
        var daysToAdd = weekday - today
        if daysToAdd <= 0 {
            daysToAdd += 7 // Next week
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)!
    }
    
    func markTodoAsAdded(_ todo: TodoSuggestion) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isAdded = true
        }
    }
    
    func markCalendarItemAsAdded(_ item: CalendarSuggestion) {
        if let index = calendarItems.firstIndex(where: { $0.id == item.id }) {
            calendarItems[index].isAdded = true
        }
    }
} 