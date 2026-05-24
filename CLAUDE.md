# VoiceDrop

Local push-to-talk dictation for macOS. Hold a hotkey, speak, release — transcript pastes at cursor.

## Stack
- Swift 5.9+, macOS 14+, Apple Silicon only
- SwiftUI (Settings/Onboarding) + AppKit (NSStatusItem, NSPanel HUD)
- AVFoundation for audio capture (16kHz mono Float32)
- Core ML with computeUnits: .cpuAndNeuralEngine (ANE required, not GPU fallback)
- Carbon RegisterEventHotKey for global hotkey
- CGEvent for clipboard paste simulation

## Project structure
- voicedropApp.swift — entry point, AppDelegate, menu bar
- HotkeyManager.swift — global hotkey registration
- AudioCaptureService.swift — AVAudioEngine, buffer accumulation
- TranscriptionService.swift — Core ML inference
- PasteService.swift — clipboard save/restore, CGEvent Cmd-V
- ModelManager.swift — download, checksum, storage
- UI/HUD/ — NSPanel floating overlay
- UI/Settings/ — SwiftUI settings panel
- UI/Onboarding/ — first launch flow

## Key constraints
- Audio NEVER written to disk — memory buffer only
- Paste must restore previous clipboard contents after 500ms
- ANE routing must be explicit — verify with Instruments
- No App Store — direct DMG distribution
- No Python runtime at runtime — Core ML .mlpackage only

## Build
- Open in VS Code with SweetPad extension
- SweetPad: Build & Run to compile and launch
- Target: macOS arm64 Debug