import AppKit
import AVFoundation
import os
import SwiftUI

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
    private var contextMenu: NSMenu!
    private let audioService = AudioCaptureService()
    private let appleTranscriber = AppleSpeechTranscriber()
    private let pasteService = PasteService()
    private let recordingState = RecordingState()
    private let onboardingManager = OnboardingManager()
    private var hudController: RecordingHUDController!
    private var onboardingWindowController: OnboardingWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var hotkeyManager = HotkeyManager()
    private var amplitudeTimer: Timer?
    private var errorResetTimer: Timer?
    private var isCurrentlyRecording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        hudController = RecordingHUDController(state: recordingState)
        setupMenuBar()

        hotkeyManager.hotKeyCode = AppSettings.shared.hotKeyCode
        hotkeyManager.onRecordingStart = { [weak self] in self?.startRecording() }
        hotkeyManager.onRecordingEnd = { [weak self] in self?.stopRecording() }
        hotkeyManager.start()

        if AppSettings.shared.transcriptionEngine == .parakeet, ParakeetManager.shared.isModelDownloaded {
            Task { await ParakeetManager.shared.prepare() }
        }

        if onboardingManager.isComplete {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            onboardingManager.onComplete = { [weak self] in
                guard let self else { return }
                onboardingWindowController?.close()
                onboardingWindowController = nil
                NSApp.setActivationPolicy(.accessory)
            }
            let wc = OnboardingWindowController(manager: onboardingManager)
            onboardingWindowController = wc
            wc.show()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        contextMenu = NSMenu()
        contextMenu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        contextMenu.addItem(.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit VoiceDrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceDrop")
        }
        statusItem?.menu = contextMenu
    }

    private func startRecording() {
        guard !isCurrentlyRecording else { return }
        isCurrentlyRecording = true
        if AppSettings.shared.soundFeedbackEnabled { NSSound(named: .init("Tink"))?.play() }
        recordingState.startDate = .now
        recordingState.amplitudeBars = Array(repeating: 0.1, count: 40)
        do {
            try audioService.startCapture()
        } catch {
            Logger.app.error("Audio capture error: \(error.localizedDescription, privacy: .public)")
            isCurrentlyRecording = false
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

    private func stopRecording() {
        guard isCurrentlyRecording else { return }
        isCurrentlyRecording = false
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        hudController.hide()
        let (buffer, duration) = audioService.stopCapture()
        setIdleIcon()
        Logger.app.notice("stopRecording — duration: \(String(format: "%.2f", duration), privacy: .public)s")
        guard duration >= 0.5, let buffer else {
            Logger.app.notice("Recording too short, ignoring")
            return
        }
        if AppSettings.shared.soundFeedbackEnabled { NSSound(named: .init("Pop"))?.play() }
        Task {
            let text = await transcribe(buffer)
            Logger.app.notice("Transcript: \(text, privacy: .public)")
            guard !text.isEmpty else { return }
            Logger.app.notice("Pasting…")
            pasteService.paste(text)
        }
    }

    private func transcribe(_ buffer: AVAudioPCMBuffer) async -> String {
        if AppSettings.shared.transcriptionEngine == .parakeet, ParakeetManager.shared.isReady {
            Logger.app.notice("Transcribing (Parakeet)…")
            return await ParakeetManager.shared.transcribe(buffer)
        }
        Logger.app.notice("Transcribing (Apple Speech)…")
        return await appleTranscriber.transcribe(buffer)
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

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }
}
