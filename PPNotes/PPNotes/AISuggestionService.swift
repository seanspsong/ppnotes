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
        
        print("🎯 [AI Suggestion] Starting analysis for transcription: '\(transcription)'")
        isAnalyzing = true
        error = nil
        
        do {
            // Initialize session if needed
            if session == nil {
                session = LanguageModelSession(
                    instructions: "You are a helpful AI assistant specialized in extracting actionable items from voice note transcriptions. You analyze text to identify todos, tasks, and calendar events."
                )
                print("✅ [AI Suggestion] Initialized new LanguageModelSession")
            }
            
            // Extract todos and calendar items sequentially (FoundationModels doesn't support concurrent calls)
            let extractedTodos = await extractTodos(from: transcription)
            let extractedCalendar = await extractCalendarItems(from: transcription)
            
            todos = extractedTodos
            calendarItems = extractedCalendar
            
            print("📊 [AI Suggestion] Analysis complete: \(extractedTodos.count) todos, \(extractedCalendar.count) calendar items")
            
        } catch {
            self.error = "Failed to analyze suggestions: \(error.localizedDescription)"
            print("❌ [AI Suggestion] Error: \(error.localizedDescription)")
        }
        
        isAnalyzing = false
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
        let prompt = """
        Analyze this voice note transcription and extract any events, meetings, appointments, or scheduling requests.
        
        Format your response as JSON with this structure:
        {
            "events": [
                {
                    "title": "Event title",
                    "notes": "Additional details if any",
                    "suggestedDate": "2025-01-25T15:30:00Z",
                    "duration": 3600,
                    "extractedText": "Original text from transcription"
                }
            ]
        }
        
        Rules:
        - Extract events, meetings, appointments, and scheduling requests
        - Include items even without specific dates/times (use null for suggestedDate)
        - Look for keywords like: schedule, meeting, appointment, call, event, dinner, lunch, etc.
        - Use ISO 8601 format for suggestedDate when date/time is mentioned
        - Duration in seconds (default 3600 for 1 hour if not specified)
        - Include context in notes if helpful
        - extractedText should be the original phrase/sentence from transcription
        
        Examples of what to extract:
        - "Schedule meeting with Aaron" → extract as calendar item
        - "Call mom tomorrow at 3pm" → extract with specific date/time
        - "Doctor appointment next Friday" → extract with estimated date
        - "Dinner with friends" → extract even without specific time
        
        Current date/time for reference: \(Date().ISO8601Format())
        
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
            
            return TodoSuggestion(
                title: title,
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
        
        let dateFormatter = ISO8601DateFormatter()
        
        let results = eventsArray.compactMap { eventDict -> CalendarSuggestion? in
            guard let title = eventDict["title"] as? String,
                  let extractedText = eventDict["extractedText"] as? String else {
                print("❌ [AI Calendar] Missing required fields in calendar item")
                return nil
            }
            
            let suggestedDate: Date?
            if let dateString = eventDict["suggestedDate"] as? String {
                suggestedDate = dateFormatter.date(from: dateString)
            } else {
                suggestedDate = nil
            }
            
            return CalendarSuggestion(
                title: title,
                notes: eventDict["notes"] as? String,
                suggestedDate: suggestedDate,
                duration: eventDict["duration"] as? TimeInterval,
                extractedText: extractedText
            )
        }
        
        print("✅ [AI Calendar] Parsed \(results.count) calendar items")
        return results
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