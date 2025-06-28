//
//  VoiceNote.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import Foundation

struct VoiceNote: Identifiable, Codable {
    let id: UUID
    let title: String
    let audioFileName: String
    let duration: TimeInterval
    let timestamp: Date
    let transcription: String
    
    init(title: String, audioFileName: String, duration: TimeInterval, timestamp: Date, transcription: String) {
        self.id = UUID()
        self.title = title
        self.audioFileName = audioFileName
        self.duration = duration
        self.timestamp = timestamp
        self.transcription = transcription
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
} 