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
    
    // Button size specifications from design
    private let idleSize: CGFloat = 80
    private let recordingSize: CGFloat = 100
    
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
        VStack(spacing: 16) {
            // Recording timer (only visible when recording)
            if viewModel.isRecording {
                Text(viewModel.formattedRemainingTime)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(timerColor)
                    .animation(.easeInOut(duration: 0.3), value: timerColor)
            }
            
            // Delete mode message
            if viewModel.isDeleteMode {
                Text("Delete mode active")
                    .font(.caption)
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
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 4)
                            .frame(width: currentButtonSize + 20, height: currentButtonSize + 20)
                            .scaleEffect(waveformScale)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: waveformScale)
                    }
                    
                    // Microphone icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32, weight: .medium))
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
            if !viewModel.isRecording && !viewModel.isDeleteMode {
                Text("Push to Talk")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            } else if viewModel.isDeleteMode {
                Text("Tap 'Done' to exit")
                    .font(.footnote)
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

#Preview {
    VStack {
        RecordingButton(viewModel: VoiceNotesViewModel())
    }
    .padding()
    .background(Color(.systemBackground))
} 