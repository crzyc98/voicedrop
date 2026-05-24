import SwiftUI
import AppKit

@main
struct VoiceDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private let hotkeyManager = HotkeyManager()
    private let audioService = AudioCaptureService()
    private let recordingState = RecordingState()
    private var hudController: RecordingHUDController!
    private var amplitudeTimer: Timer?
    private var errorResetTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hudController = RecordingHUDController(state: recordingState)
        setupMenuBar()
        setupHotkey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceDrop")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit VoiceDrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupHotkey() {
        hotkeyManager.onRecordingStart = { [weak self] in
            guard let self else { return }
            recordingState.startDate = .now
            recordingState.amplitudeBars = Array(repeating: 0.1, count: 20)
            do {
                try audioService.startCapture()
            } catch {
                print("[VoiceDrop] Audio capture error: \(error)")
                return
            }
            hudController.show()
            setRecordingIcon()
            amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let amp = self.audioService.currentAmplitude
                    self.recordingState.amplitudeBars.removeFirst()
                    self.recordingState.amplitudeBars.append(amp)
                }
            }
        }

        hotkeyManager.onRecordingEnd = { [weak self] in
            guard let self else { return }
            amplitudeTimer?.invalidate()
            amplitudeTimer = nil
            hudController.hide()
            let duration = audioService.stopCapture()
            guard duration >= 0.5 else {
                setIdleIcon()
                return
            }
            print(String(format: "[VoiceDrop] Recording stopped — buffer: %.2fs", duration))
            setIdleIcon()
        }

        hotkeyManager.start()
    }

    private func setIdleIcon() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceDrop")
        button.contentTintColor = nil
    }

    private func setRecordingIcon() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceDrop")
        button.contentTintColor = NSColor(red: 0.878, green: 0.482, blue: 0.224, alpha: 1)
    }

    func setErrorIcon() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: "VoiceDrop — error")
        button.contentTintColor = nil
        errorResetTimer?.invalidate()
        errorResetTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.setIdleIcon()
        }
    }

    @objc func openSettings() {}
}
