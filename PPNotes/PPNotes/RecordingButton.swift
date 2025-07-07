//
//  RecordingButton.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI

struct RecordingButton: View {
    @ObservedObject var viewModel: VoiceNotesViewModel
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    // Optional parameters for iPad customization
    let scaleEffect: CGFloat
    let showTimer: Bool
    let showLabel: Bool
    
    init(
        viewModel: VoiceNotesViewModel,
        scaleEffect: CGFloat = 1.0,
        showTimer: Bool = true,
        showLabel: Bool = true
    ) {
        self.viewModel = viewModel
        self.scaleEffect = scaleEffect
        self.showTimer = showTimer
        self.showLabel = showLabel
    }
    
    // Adaptive button sizes based on device and scale
    private var idleSize: CGFloat {
        let baseSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 70 : 80
        return baseSize * scaleEffect
    }
    
    private var recordingSize: CGFloat {
        let baseSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 85 : 100
        return baseSize * scaleEffect
    }
    
    // Adaptive icon size
    private var iconSize: CGFloat {
        let baseSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 28 : 32
        return baseSize * scaleEffect
    }
    
    // Timer color based on remaining time
    private var timerColor: Color {
        if viewModel.isWarningTime {
            return .red
        } else if viewModel.isNearWarningTime {
            return .orange
        } else {
            return .primary
        }
    }
    
    // Button color based on state
    private var buttonColor: Color {
        if viewModel.isDeleteMode {
            return Color.secondary.opacity(0.3)
        } else {
            return Color.accentColor // Full theme color for both states
        }
    }
    
    var body: some View {
        VStack(spacing: 16 * scaleEffect) {
            // Recording timer (only visible when recording and showTimer is true)
            if viewModel.isRecording && showTimer {
                Text(viewModel.formattedRemainingTime)
                    .font(.system(size: 18 * scaleEffect, weight: .medium))
                    .foregroundColor(timerColor)
                    .animation(.easeInOut(duration: 0.3), value: timerColor)
            }
            
            // Delete mode message
            if viewModel.isDeleteMode && showLabel {
                Text("Delete mode active")
                    .font(.system(size: 12 * scaleEffect))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            
            // Main recording button
            Button(action: {}) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(buttonColor)
                        .frame(width: currentButtonSize, height: currentButtonSize)
                        .scaleEffect(pulseEffect)
                        .animation(.easeInOut(duration: 0.3), value: currentButtonSize)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    // Waveform ring (only when recording)
                    if viewModel.isRecording {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 4 * scaleEffect)
                            .frame(width: currentButtonSize + 20 * scaleEffect, height: currentButtonSize + 20 * scaleEffect)
                            .scaleEffect(waveformScale)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: waveformScale)
                    }
                    
                    // Microphone icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isPressed)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Record voice note")
            .accessibilityHint("Double-tap and hold to record")
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: 50,
                pressing: { pressing in
                    handlePressStateChange(pressing)
                },
                perform: {}
            )
            .onAppear {
                startPulseAnimation()
            }
            
            // Push to Talk label
            if !viewModel.isRecording && !viewModel.isDeleteMode && showLabel {
                Text("Push to Talk")
                    .font(.system(size: 12 * scaleEffect))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            } else if viewModel.isDeleteMode && showLabel {
                Text("Tap 'Done' to exit")
                    .font(.system(size: 12 * scaleEffect))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
    }
    
    private var currentButtonSize: CGFloat {
        viewModel.isRecording ? recordingSize : idleSize
    }
    
    private var pulseEffect: CGFloat {
        if viewModel.isRecording || viewModel.isDeleteMode {
            return 1.0
        } else {
            return pulseAnimation ? 1.05 : 1.0
        }
    }
    
    private var waveformScale: CGFloat {
        viewModel.isRecording ? 1.2 : 1.0
    }
    
    private func handlePressStateChange(_ pressing: Bool) {
        // Don't allow recording in delete mode
        if viewModel.isDeleteMode {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = pressing
        }
        
        if pressing && !viewModel.isRecording {
            viewModel.startRecording()
        } else if !pressing && viewModel.isRecording {
            viewModel.stopRecording()
        }
    }
    
    private func startPulseAnimation() {
        if !viewModel.isRecording && !viewModel.isDeleteMode {
            pulseAnimation = true
        }
    }
}

// iPad-specific compact recording button for sidebar
struct CompactRecordingButton: View {
    @ObservedObject var viewModel: VoiceNotesViewModel
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    private let buttonSize: CGFloat = 50
    private let iconSize: CGFloat = 20
    
    var body: some View {
        Button(action: {}) {
            ZStack {
                // Background circle
                Circle()
                    .fill(viewModel.isDeleteMode ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(pulseEffect)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Waveform ring (only when recording)
                if viewModel.isRecording {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 2)
                        .frame(width: buttonSize + 8, height: buttonSize + 8)
                        .scaleEffect(waveformScale)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: waveformScale)
                }
                
                // Microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Record voice note")
        .accessibilityHint("Double-tap and hold to record")
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: 50,
            pressing: { pressing in
                handlePressStateChange(pressing)
            },
            perform: {}
        )
        .onAppear {
            startPulseAnimation()
        }
    }
    
    private var pulseEffect: CGFloat {
        if viewModel.isRecording || viewModel.isDeleteMode {
            return 1.0
        } else {
            return pulseAnimation ? 1.05 : 1.0
        }
    }
    
    private var waveformScale: CGFloat {
        viewModel.isRecording ? 1.2 : 1.0
    }
    
    private func handlePressStateChange(_ pressing: Bool) {
        // Don't allow recording in delete mode
        if viewModel.isDeleteMode {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = pressing
        }
        
        if pressing && !viewModel.isRecording {
            viewModel.startRecording()
        } else if !pressing && viewModel.isRecording {
            viewModel.stopRecording()
        }
    }
    
    private func startPulseAnimation() {
        if !viewModel.isRecording && !viewModel.isDeleteMode {
            pulseAnimation = true
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Standard recording button
        RecordingButton(viewModel: VoiceNotesViewModel())
        
        // Scaled recording button for iPad
        RecordingButton(
            viewModel: VoiceNotesViewModel(),
            scaleEffect: 0.8,
            showTimer: false,
            showLabel: false
        )
        
        // Compact recording button
        CompactRecordingButton(viewModel: VoiceNotesViewModel())
    }
    .padding()
    .background(Color(.systemBackground))
} 