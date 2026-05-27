# VoiceDrop

Local push-to-talk dictation for macOS. Hold a hotkey, speak, release — transcript pastes at cursor.

## Stack
- Swift 5.9+, macOS 14+, Apple Silicon only
- SwiftUI (Settings/Onboarding) + AppKit (NSStatusItem, NSPanel HUD)
- AVFoundation for audio capture (16kHz mono Float32)
- Core ML with computeUnits: .cpuAndNeuralEngine (ANE required, not GPU fallback)
- FluidAudio — third-party Swift package wrapping Parakeet TDT v3 Core ML models
- Carbon RegisterEventHotKey for global hotkey
- CGEvent for clipboard paste simulation
- ServiceManagement (SMAppService) for launch-at-login

## Project structure
- voicedropApp.swift — entry point, AppDelegate, menu bar, recording loop
- HotkeyManager.swift — global hotkey registration (Carbon)
- AudioCaptureService.swift — AVAudioEngine, buffer accumulation, amplitude metering
- TranscriptionService.swift — AppleSpeechTranscriber (SFSpeechRecognizer, on-device batch)
- ModelManager.swift — ParakeetManager: FluidAudio download, load, transcribe
- PasteService.swift — clipboard save/restore, CGEvent Cmd-V
- AppSettings.swift — UserDefaults-backed @Observable settings singleton
- Log.swift — os.Logger wrapper
- OnboardingManager.swift — step machine; persists completion to UserDefaults
- OnboardingView.swift — 2-step SwiftUI onboarding (permissions + done)
- OnboardingWindowController.swift — NSWindow wrapper for onboarding
- SettingsView.swift — SwiftUI settings panel (engine picker removed; hotkey, permissions, launch-at-login, diagnostics)
- SettingsWindowController.swift — NSWindow wrapper for settings
- RecordingState.swift — @Observable amplitude bars + start date for HUD
- RecordingHUDView.swift — floating waveform HUD (NSPanel)
- RecordingHUDController.swift — show/hide/position NSPanel

## Transcription engines
Two engines selectable at runtime via `AppSettings.transcriptionEngine`:
- `.parakeet` — FluidAudio `AsrManager` + `TdtDecoderState`, downloads ~600 MB model on first use, ANE-accelerated
- `.appleSpeech` — `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, no download needed

AppDelegate preloads Parakeet on launch if already downloaded.

## Key constraints
- Audio NEVER written to disk — memory buffer only
- Paste must restore previous clipboard contents after 500ms
- ANE routing must be explicit — verify with Instruments
- No App Store — direct DMG distribution
- No Python runtime at runtime — Core ML .mlpackage only
- Minimum recording duration: 0.5s (shorter clips are silently discarded)

## Build
- Open in VS Code with SweetPad extension
- SweetPad: Build & Run to compile and launch
- Target: macOS arm64 Debug
- Launch via `open` (not SweetPad Run) for TCC permissions on macOS 26; avoid duplicate bundle IDs
