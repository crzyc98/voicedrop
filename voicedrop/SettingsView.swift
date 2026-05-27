import AppKit
import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var accessibilityGranted = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.title2.bold())
                Text("Tune how VoiceDrop behaves.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            VStack(spacing: 0) {
                SettingsRow("Push-to-talk",
                            description: "Hold ` (backtick) anywhere to record. Release to paste.")

                Divider().padding(.leading, 20)

                SettingsRow("Microphone", description: "Required for recording your voice.") {
                    GrantedBadge(granted: micGranted)
                }

                Divider().padding(.leading, 20)

                SettingsRow("Accessibility",
                            description: "Required for pasting transcripts at your cursor.") {
                    GrantedBadge(granted: accessibilityGranted)
                }

                Divider().padding(.leading, 20)

                SettingsRow("Launch at login",
                            description: "Start VoiceDrop automatically when you log in.") {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider().padding(.leading, 20)

                SettingsRow("Report an issue",
                            description: "Copies a diagnostic report to your clipboard so you can paste it into the contact form. Transcript content is never logged.") {
                    Button("Report") { copyDiagnosticReport() }
                        .buttonStyle(.bordered)
                }

                Divider().padding(.leading, 20)

                SettingsRow("Diagnostic log",
                            description: "Open the local log file. Useful when reporting a bug.") {
                    Button("Open") { openLog() }
                        .buttonStyle(.bordered)
                }

                Divider().padding(.leading, 20)

                SettingsRow("Version", description: versionString)
            }
        }
        .frame(width: 380)
        .onAppear { refresh() }
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func refresh() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func copyDiagnosticReport() {
        let report = "VoiceDrop Diagnostic\nVersion: \(versionString)\nMic: \(micGranted)\nAccessibility: \(accessibilityGranted)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private func openLog() {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        NSWorkspace.shared.open(base.appendingPathComponent("VoiceDrop"))
    }
}

// MARK: - Shared row layout

private struct SettingsRow<Action: View>: View {
    let title: String
    let description: String
    @ViewBuilder let action: () -> Action

    init(_ title: String, description: String, @ViewBuilder action: @escaping () -> Action) {
        self.title = title
        self.description = description
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            action()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private extension SettingsRow where Action == EmptyView {
    init(_ title: String, description: String) {
        self.init(title, description: description) { EmptyView() }
    }
}

private struct GrantedBadge: View {
    var granted: Bool

    var body: some View {
        if granted {
            Text("Granted")
                .foregroundStyle(.green)
        }
    }
}
