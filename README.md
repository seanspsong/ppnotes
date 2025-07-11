# PPNotes - Personal & Private Voice Notes

A voice note-taking app that keeps everything on your device.

## What is PPNotes?

PPNotes (Personal & Private Notes) is an iOS app for taking voice notes using Apple's on-device LLM technology. Your voice recordings and transcriptions never leave your device.

## Features

- 🎙️ Voice note recording with push-to-talk
- 🤖 On-device LLM transcription (iOS 26)
- 🔒 Complete privacy - no cloud, no servers
- 📱 Native iOS experience
- 🌍 Multi-language support (7 languages)
- 🎨 Beautiful staggered card layout with random transforms
- 📱 Responsive iPad layout with orientation support
- ✨ Smooth zoom animations and transitions
- 🎵 Audio playback with waveform visualization
- 🗑️ Delete mode with intuitive long-press gestures
- 📅 Calendar event integration (EventKit)
- 💡 AI-powered content suggestions
- 🎯 Auto-generated smart titles from transcription

## iPad Experience

PPNotes features a specially designed iPad interface that adapts beautifully to different orientations and screen sizes:

### Dynamic Grid Layout
- **Responsive Design**: Automatically adjusts to screen size and orientation
- **Sidebar-Aware**: Adapts column count based on split view configuration
- **Layout Matrix**:
  - Vertical iPad (sidebar visible): 2 cards per row
  - Vertical iPad (sidebar hidden): 3 cards per row  
  - Horizontal iPad (sidebar visible): 3 cards per row
  - Horizontal iPad (sidebar hidden): 4 cards per row

### Beautiful Visual Design
- **Random Transforms**: Each card has unique rotation, scale, and positioning
- **Pinterest-Style Layout**: Cards arranged with natural, organic feel
- **Consistent Randomization**: Transform values based on card index for repeatability
- **Enhanced Shadows**: Dynamic shadows that respond to card positioning
- **Smooth Animations**: Spring-based animations throughout the interface

### iPad-Optimized Navigation
- **Zoom-from-Source Animation**: Detailed views zoom from their source card
- **Modal Presentation**: Beautiful 24pt rounded corners with gradient headers
- **Gesture Dismissal**: Swipe down to dismiss with reverse animation
- **Maintains Context**: Cards keep their unique transforms during navigation

### Touch-Optimized Interactions
- **Flexible Grid Items**: Cards resize between 120-200pt for optimal touch targets
- **Enhanced Spacing**: 32pt row spacing, 24pt column spacing for comfortable interaction
- **Visual Feedback**: Immediate response to touch with proper animation feedback

## Requirements

- iOS 26.0+
- Device with on-device LLM support

## Language Support

PPNotes features an intuitive language selection interface that allows you to choose your preferred transcription language. The app uses iOS 26's advanced SpeechTranscriber framework for on-device voice transcription.

### Supported Languages
- 🇺🇸 **English** (en-US)
- 🇯🇵 **Japanese** (ja-JP) - 日本語
- 🇨🇳 **Chinese** (zh-CN) - 中文
- 🇮🇹 **Italian** (it-IT) - Italiano
- 🇩🇪 **German** (de-DE) - Deutsch
- 🇫🇷 **French** (fr-FR) - Français
- 🇪🇸 **Spanish** (es-ES) - Español

### Language Selection Features
- **First Launch Setup**: Beautiful onboarding screen to select your preferred language
- **Easy Language Changes**: Access language settings anytime through the app settings
- **Smart Fallback**: Automatic fallback to SFSpeechRecognizer if SpeechTranscriber is unavailable
- **Device Integration**: Automatically detects and suggests your device's language as default

> **Privacy Note**: All transcription happens entirely on-device with no internet required. Your voice data never leaves your device, regardless of the selected language.

## Privacy

Everything stays on your device. No data is sent to external servers or the cloud.

---

# Design Document

## Design Philosophy

Following Apple Human Interface Guidelines, PPNotes prioritizes **simplicity**, **clarity**, and **intuitive interactions**. The app embraces iOS design patterns while focusing on privacy-first voice note capture.

## Core Interaction Model

### Push-to-Talk Recording
- **Primary Action**: Single prominent button at bottom of screen
- **Interaction**: Press and hold to record, release to stop
- **Recording Limits**: Maximum 3 minutes per recording
- **Visual Feedback**: 
  - Button expands and glows during recording
  - Subtle haptic feedback on press
  - Real-time audio waveform visualization
  - Recording timer display with countdown
- **Time Warnings**:
  - Vibration alert at 10 seconds remaining
  - Timer color changes to amber at 30 seconds remaining
  - Timer color changes to red at 10 seconds remaining
  - Auto-stop at 3 minute limit

### Voice Note Cards
- **Visual Metaphor**: Each recording becomes a "card" - like digital sticky notes
- **Layout**: Staggered card layout filling screen from top-left
- **Card Appearance**: 
  - Rounded corners (12pt radius)
  - Subtle shadow for depth
  - Timestamp header
  - Waveform preview
  - Auto-generated title from transcription

## User Interface Layout

### Main Screen Structure
```
┌─────────────────────────────┐
│ PPNotes          [Settings] │ ← Navigation Bar
├─────────────────────────────┤
│                             │
│  [Card]    [Card]           │ ← Voice Note Cards
│                             │   (Staggered Layout)
│     [Card]    [Card]        │
│                             │
│  [Card]         [Card]      │
│                             │
│                             │
│                             │
├─────────────────────────────┤
│     🎙️ Push to Talk        │ ← Recording Button
└─────────────────────────────┘
```

### Recording Button Specifications
- **Size**: 80pt diameter (optimal touch target)
- **Position**: Bottom safe area + 20pt margin
- **Style**: 
  - Circular with microphone icon
  - Primary system color (iOS Accent Color)
  - Semi-transparent background when inactive
  - Solid color with scale animation when active
- **States**:
  - Idle: Subtle pulse animation
  - Recording: Expanded (100pt), blue accent, waveform ring
  - Recording (30s left): Amber timer color
  - Recording (10s left): Red timer color + vibration
  - Processing: Spinner overlay

### Voice Note Card Design
- **Dimensions**: Variable width (150-200pt), height (120-160pt)
- **Content Hierarchy**:
  1. Timestamp (secondary text, top-right)
  2. Auto-generated title (headline, 2-3 words from transcription)
  3. Waveform visualization (compact)
  4. Duration badge (bottom-left)
- **Interaction**: Tap to play, long-press for options menu

## Accessibility Design

### VoiceOver Support
- Recording button: "Record voice note, button. Double-tap and hold to record"
- Cards: "Voice note, [title], [duration], [timestamp]. Double-tap to play"
- Clear audio descriptions for all UI elements

### Motor Accessibility
- Alternative to push-to-talk: Toggle recording mode for users who cannot maintain pressure
- Large touch targets (minimum 44pt)
- Voice Control support for hands-free operation

### Visual Accessibility
- High contrast mode support
- Dynamic Type scaling for all text
- Reduced motion alternatives for animations
- Color-blind friendly visual indicators

## Audio & Transcription UX

### Recording States
1. **Idle**: Ready to record, subtle visual cues
2. **Recording (0-2:30)**: Clear visual feedback, waveform, blue timer
3. **Recording (2:30-2:50)**: Timer turns amber, warning approaching limit
4. **Recording (2:50-3:00)**: Timer turns red, vibration at 2:50
5. **Auto-stop**: Recording stops automatically at 3:00 limit
6. **Processing**: Brief loading state for transcription
7. **Complete**: Card appears with smooth animation

### Transcription Integration
- **Title Generation**: Extract 2-3 meaningful words for card title
- **Search**: Enable finding notes by transcribed content

## Visual Design System

### Color Palette
- **Primary**: iOS System Accent Color (user customizable)
- **Current Theme**: Purple #8A2BE2 (BlueViolet)
  - Light Mode: RGB(138, 43, 226) = (0.541, 0.169, 0.886)
  - Dark Mode: RGB(153, 56, 235) = (0.600, 0.220, 0.920)
- **Recording State**: System Red with 80% opacity
- **Background**: iOS System Background (adaptive for light/dark mode)
- **Cards**: iOS Secondary System Background
- **Text**: iOS Label colors (adaptive)

### Typography
- **Card Titles**: SF Pro Text, Headline style
- **Timestamps**: SF Pro Text, Caption style
- **Duration**: SF Pro Text, Footnote style, Medium weight

### Animation Principles
- **Smooth & Natural**: 0.3s ease-in-out for most transitions
- **Responsive Feedback**: Immediate visual response to touch
- **Card Entrance**: Gentle scale + fade animation
- **Recording Pulse**: Subtle breathing animation (2s cycle)

## Layout & Organization

### Card Arrangement Strategy
- **Algorithm**: Staggered grid with random slight rotation (-5° to +5°)
- **Spacing**: 16pt minimum between cards
- **Overflow**: Vertical scrolling when screen fills
- **Empty State**: Friendly illustration with recording tips

### Information Architecture
```
PPNotes App
├── Main Screen (Voice Notes Grid)
├── Settings
│   ├── Recording Quality
│   ├── Transcription Language
│   ├── Privacy Settings
│   └── About
└── Individual Note View
    ├── Full Transcription
    ├── Edit Title
    ├── Share Options
    └── Delete
```

## Interaction Patterns

### Recording Flow
1. User press and holds recording button
2. Haptic feedback confirms recording start
3. Button animates (expand + color change)
4. Real-time waveform appears
5. Timer shows recording duration (countdown from 3:00)
6. **Time warnings during recording**:
   - At 30s remaining: Timer turns amber
   - At 10s remaining: Timer turns red + vibration alert
   - At 0s: Auto-stop recording
7. User releases button to stop (or auto-stop at limit)
8. Brief processing state
9. New card animates into view

### Playback Flow
1. User taps voice note card
2. Card highlights with play indicator
3. Audio plays with progress visualization
4. Tap again to pause/stop
5. Auto-advance to next note (optional setting)

### Management Actions
- **Swipe to Delete**: Standard iOS pattern
- **Long Press**: Context menu (Play, Share, Delete, Edit Title)
- **Pull to Refresh**: Re-process transcriptions with latest model

This design prioritizes the core voice recording experience while maintaining Apple's design excellence and accessibility standards. 
