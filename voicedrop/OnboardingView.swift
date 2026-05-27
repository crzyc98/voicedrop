import AVFoundation
import AppKit
import Speech
import SwiftUI

// MARK: - Root view

struct OnboardingView: View {
    var manager: OnboardingManager

    var body: some View {
        ZStack(alignment: .bottom) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 44)

            PaginationDots(steps: OnboardingManager.Step.allCases, current: manager.currentStep)
                .padding(.bottom, 16)
        }
        .frame(width: 500, height: 520)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch manager.currentStep {
        case .permissions:
            PermissionsStepView(manager: manager)
        case .done:
            DoneStepView(manager: manager)
        }
    }
}

// MARK: - Pagination dots

private struct PaginationDots: View {
    var steps: [OnboardingManager.Step]
    var current: OnboardingManager.Step

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps, id: \.self) { step in
                Capsule()
                    .fill(step == current ? voiceDropOrange : Color.secondary.opacity(0.3))
                    .frame(width: step == current ? 20 : 8, height: 8)
                    .animation(.spring(duration: 0.25), value: current)
            }
        }
    }
}

// MARK: - Step 1: Permissions

private struct PermissionsStepView: View {
    var manager: OnboardingManager
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var speechStatus = SFSpeechRecognizer.authorizationStatus()
    @State private var requesting = false

    private var bothGranted: Bool {
        micStatus == .authorized && speechStatus == .authorized
    }

    private var anyDenied: Bool {
        micStatus == .denied || speechStatus == .denied
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.and.signal.meter")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Allow Access")
                    .font(.title2.bold())
                Text("VoiceDrop needs microphone and speech recognition access. Audio is transcribed on-device and never leaves your Mac.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                PermissionRow(icon: "mic.fill", label: "Microphone", granted: micStatus == .authorized)
                PermissionRow(icon: "waveform", label: "Speech Recognition", granted: speechStatus == .authorized)
            }

            actionButton
        }
        .padding(32)
        .onAppear {
            refresh()
            if bothGranted { manager.advance() }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if bothGranted {
            Button("Continue") { manager.advance() }
                .buttonStyle(OrangeButtonStyle())
                .frame(maxWidth: 280)
        } else if anyDenied {
            VStack(spacing: 10) {
                Text("Permission denied — enable access in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
                .buttonStyle(OrangeButtonStyle())
                .frame(maxWidth: 280)
            }
        } else {
            Button(requesting ? "Requesting…" : "Grant Access") { requestPermissions() }
                .buttonStyle(OrangeButtonStyle())
                .frame(maxWidth: 280)
                .disabled(requesting)
        }
    }

    private func refresh() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
    }

    private func requestPermissions() {
        requesting = true
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                speechStatus = status
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        micStatus = granted ? .authorized : .denied
                        requesting = false
                        refresh()
                        if bothGranted { manager.advance() }
                    }
                }
            }
        }
    }
}

private struct PermissionRow: View {
    var icon: String
    var label: String
    var granted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(label)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
        }
        .frame(maxWidth: 260)
    }
}

// MARK: - Step 2: Done

private struct DoneStepView: View {
    var manager: OnboardingManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("All set")
                    .font(.largeTitle.bold())
                Text("Hold ` (backtick), talk, release. Your words appear at your cursor.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("VoiceDrop lives in your menu bar, open settings from there.")

                Button("Get started") { manager.advance() }
                    .buttonStyle(OrangeButtonStyle())
                    .frame(maxWidth: 280)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Shared styles

private let voiceDropOrange = Color(red: 0.93, green: 0.58, blue: 0.22)

private struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(voiceDropOrange.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
