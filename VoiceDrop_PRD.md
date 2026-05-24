# VoiceDrop for macOS — Product Requirements Document

**Version:** 1.0  
**Status:** Draft  
**Platform:** macOS 14+ · Apple Silicon  
**Date:** May 2026

> **TL;DR:** VoiceDrop is a lightweight Swift menu bar app. Hold a hotkey, speak, release — your words paste at the cursor in any app. All inference runs locally on Apple Silicon via Core ML and the Neural Engine using NVIDIA's Parakeet TDT 0.6B v3. No cloud, no Python runtime, no account, no subscription.

---

## 1. Overview & Motivation

### 1.1 Problem Statement

Existing dictation tools on macOS force a compromise: Apple's built-in dictation cuts off mid-sentence and produces mediocre accuracy, while cloud-based alternatives (Wispr Flow, Superwhisper) send audio to third-party servers and charge monthly subscriptions. There is no lightweight, private, high-accuracy option that a developer can own outright.

### 1.2 Solution

VoiceDrop is a macOS menu bar app built in Swift that implements push-to-talk dictation entirely on-device. The user holds a hotkey, speaks, and releases. The transcript pastes at the cursor automatically. The speech model runs on Apple's Neural Engine — the same hardware that powers Face ID — so transcription is near-instantaneous and the CPU/GPU remain free for other work.

The app ships as a 2 MB binary. On first launch it downloads the ~600 MB Parakeet TDT v3 model once. After that, there is no setup surface, no runtime to manage, and zero network activity.

### 1.3 Inspiration & Prior Art

Parakeety (parakeety.com) demonstrates this product concept at commercial quality — a native Swift menu bar app wrapping Parakeet TDT v3 with the same push-to-talk pattern. Feedback from that developer confirms the key architectural decisions: go fully native Swift (no Python runtime, no virtual envs), and explicitly route inference through the Apple Neural Engine rather than falling back to CPU or GPU. The throughput difference on ANE is significant.

VoiceDrop is a personal implementation of the same pattern. No sandboxing constraints, configurable hotkey, model licensed CC BY 4.0.

### 1.4 Goals

- Zero audio ever leaves the machine — no network requests after initial model download
- Hotkey-to-paste latency under 1 second for typical utterances (5–15 seconds of speech)
- Accurate transcription of conversational English including technical vocabulary
- Minimal UI footprint — menu bar only, no Dock entry, no persistent window
- Fully native Swift — no Python runtime, no virtual environments, no setup friction for end users
- Single developer buildable over a weekend

### 1.5 Non-Goals

- iOS or iPadOS support (separate future project)
- Real-time streaming transcription (batch-on-release is sufficient for v1.0)
- Speaker diarization or multi-speaker support
- Multilingual support beyond Parakeet TDT v3's built-in 25 European languages
- App Store distribution (sandboxing conflicts with accessibility paste)

---

## 2. Target Users

### 2.1 Primary User Profile

| Attribute | Detail |
|---|---|
| Role | Knowledge worker — analytics, writing, and executive communication are primary activities |
| Hardware | MacBook Pro with Apple Silicon (M-series), macOS 14 Sonoma or later |
| Use pattern | Frequent dictation across apps: Slack, Mail, Notion, Claude, browser text fields, VS Code |
| Privacy stance | High — unwilling to send voice audio to third-party cloud services |
| Technical level | Developer-comfortable — installs from outside App Store, comfortable in Terminal |
| Pain point | Cloud dictation breaks focus with round-trip latency and monthly fees; Apple Dictation accuracy is insufficient for professional use |

### 2.2 Secondary Users

- Researchers and analysts who dictate notes into academic tools (Obsidian, Zotero, Word)
- Writers who prefer voice-first drafting
- Developers who want voice input in their IDE without a cloud dependency

---

## 3. Functional Requirements

### 3.1 Push-to-Talk Core Loop

| Step | Behavior | Priority |
|---|---|---|
| Hold hotkey | AVAudioEngine begins capturing mic audio at 16 kHz mono Float32 into a memory buffer. Floating HUD appears. | Required |
| Speak | Audio accumulates in buffer. HUD shows live waveform and elapsed time. No audio written to disk. | Required |
| Release hotkey | Capture stops. Parakeet model runs inference via Core ML on ANE. Transcript pastes at cursor via CGEvent. HUD dismisses. | Required |
| Empty audio guard | If buffer < 0.5s of audio, skip inference and dismiss HUD silently. | Required |
| Error fallback | If inference fails, copy transcript to clipboard instead of pasting and show a brief notification. | Required |

### 3.2 Hotkey

| Property | Spec |
|---|---|
| Default binding | § key (section sign — below Esc on UK/EU keyboards; backtick on US layout) |
| Customization | User can rebind via Settings — any key combination supported by macOS global hotkeys |
| Conflict handling | If selected key is already system-bound, show warning and allow override or cancel |
| Scope | Global — works regardless of which app is frontmost |

### 3.3 Recording HUD

A minimal floating overlay displayed during active recording:

- Appears anchored to the bottom-center of the screen
- Shows a live waveform animation driven by microphone amplitude
- Displays elapsed recording time (e.g. "7.3s")
- Implemented as a borderless `NSPanel` at `NSWindowLevel.floating`
- Dismisses immediately on hotkey release — no animation delay

### 3.4 Transcript Paste

| Property | Spec |
|---|---|
| Primary method | `CGEvent` keyboard simulation — synthesizes Cmd-V after placing text on the pasteboard |
| Pasteboard restore | Previous clipboard contents saved before paste and restored 500ms afterward |
| Fallback | If `CGEvent` paste fails (focus lost, secure input active), leave transcript on clipboard and notify |

### 3.5 Menu Bar App

- Single `NSStatusItem` — no Dock entry, no Cmd-Tab entry
- Icon states: idle (static mic), recording (pulsing orange indicator)
- Click menu: Settings, About, Check for Updates, Quit
- No persistent main window — all config in Settings panel

### 3.6 Settings Panel

| Setting | Behavior |
|---|---|
| Hotkey | Rebind push-to-talk key with a capture field |
| Launch at login | Toggle — default ON |
| Model info | Current model name, version, size. Button to re-download if corrupted. |
| Transcription history | Toggle for optional local log of past transcripts (default OFF) |
| Sound feedback | Optional click on recording start/stop (default OFF) |

### 3.7 First-Launch Onboarding

A single-window guided flow — walks through required setup steps and then closes permanently:

- **Step 1 — Model download:** Progress bar for Parakeet TDT 0.6B v3 (~600 MB). Resumable on interruption.
- **Step 2 — Microphone permission:** Trigger macOS dialog via `AVCaptureDevice`. Wait for Allow.
- **Step 3 — Accessibility permission:** Open System Settings to the correct Privacy pane. Detect toggle via polling within 2 seconds.
- **Step 4 — Done:** Confirm all permissions, dismiss window, show menu bar icon.

If the user quits mid-onboarding, the next launch resumes at the incomplete step.

### 3.8 Model Management

| Property | Spec |
|---|---|
| Model | `nvidia/parakeet-tdt-0.6b-v3`, CC BY 4.0 |
| Format | Core ML `.mlpackage` |
| Storage | `~/Library/Application Support/VoiceDrop/Models/` |
| Integrity | SHA-256 checksum verification after download |
| Updates | Check once per day at launch. Prompt user before downloading. |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| Metric | Target |
|---|---|
| Transcription latency | < 1.0s from hotkey release to paste for utterances up to 30s (M2 or later) |
| Audio capture start | < 100ms from hotkey press to first audio frame |
| HUD appear time | < 50ms from hotkey press |
| Memory (idle) | < 500 MB RSS with model loaded |
| Memory (inference) | < 700 MB RSS |
| CPU (idle) | < 1% — no polling loops while waiting |

### 4.2 Privacy & Security

| Property | Spec |
|---|---|
| Audio retention | Never written to disk. Buffer cleared immediately after inference. |
| Network access | Only during first-launch model download and optional once-daily update check. |
| Telemetry | None — no analytics, no crash reporting, no usage tracking. |
| Pasteboard | Previous contents restored after paste. App does not read clipboard. |

### 4.3 Reliability

- No crash on rapid successive hotkey presses
- Model reloads automatically if evicted by OS memory pressure
- Audio engine recovers gracefully if mic is disconnected mid-recording
- All error states leave the system clean — no orphaned audio sessions, no stuck HUDs

### 4.4 Compatibility

| Property | Spec |
|---|---|
| macOS minimum | macOS 14 Sonoma |
| Architecture | Apple Silicon (M1+) — mandatory for Neural Engine |
| Intel Mac | Explicitly unsupported |
| Distribution | Direct download DMG — not App Store |

---

## 5. Technical Architecture

### 5.1 Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI (Settings, Onboarding) + AppKit (NSStatusItem, NSPanel for HUD) |
| Audio capture | AVFoundation — `AVAudioEngine` input tap at 16 kHz mono Float32 |
| ML inference | Core ML — `MLModel` with `computeUnits: .cpuAndNeuralEngine` |
| Neural Engine | Explicitly targeted via Core ML compute units — **not** falling back to GPU or CPU |
| Hotkey | Carbon `RegisterEventHotKey` or [KeyboardShortcuts](https://github.com/nicklockwood/KeyboardShortcuts) SPM package |
| Clipboard paste | `CGEvent` with `CGEventCreateKeyboardEvent` for Cmd-V simulation |
| Model format | Core ML `.mlpackage` (see §5.2) |
| Packaging | Xcode → signed `.app` → DMG via `create-dmg` |

### 5.2 Core ML Model — Native Swift Path

> **Key architectural decision:** The entire stack is native Swift with no Python runtime required for end users or at runtime. The Parakeety developer confirmed this is why they went native — it eliminates all setup surface and keeps the app at 2 MB.

The Parakeet TDT v3 model ships as a Core ML `.mlpackage`. The conversion from NVIDIA NeMo is a **one-time developer step** — the resulting model file is hosted for download; end users never touch it.

**Critical performance note:** Inference must explicitly target the Apple Neural Engine, not fall back to GPU or CPU. `computeUnits: .cpuAndNeuralEngine` in Core ML achieves this. The throughput difference on ANE vs. CPU or GPU is significant — this is the difference between sub-1-second latency and a noticeably slow experience.

**Model conversion (developer, one-time):**
1. Install NVIDIA NeMo + `coremltools` in a Python 3.10 env
2. Download `parakeet-tdt-0.6b-v3.nemo` from Hugging Face
3. Export encoder to Core ML via `nemo.export.coreml` or `ct2-export` pipeline
4. Implement CTC/TDT greedy decoder natively in Swift (no Python at runtime)
5. Validate on-device accuracy against reference Python inference on 20 test utterances
6. Package as `.mlpackage`, compute SHA-256, host for first-launch download

The end user never sees Python. The app downloads the pre-converted `.mlpackage` and loads it directly via `MLModel`.

### 5.3 Data Flow

```
Hotkey press
  → HotkeyManager fires recordingDidStart
  → AudioCaptureService: AVAudioEngine tap starts, 16kHz mono Float32 → AudioBuffer
  → HUD appears (NSPanel.makeKeyAndOrderFront)

[user speaks]

Hotkey release
  → HotkeyManager fires recordingDidEnd
  → AudioCaptureService stops tap
  → TranscriptionService: AudioBuffer → Core ML (ANE) → String transcript
  → PasteService: save pasteboard → write transcript → CGEvent Cmd-V → restore pasteboard (500ms delay)
  → HUD dismisses
```

All steps run on the main actor in v1.0 for simplicity. Background actor for inference is a v1.1 optimization.

### 5.4 Project Structure

```
VoiceDrop/
├── App/                    # Entry point, AppDelegate, menu bar setup
├── HotkeyManager/          # Global hotkey registration, press/release publishing
├── AudioCaptureService/    # AVAudioEngine lifecycle, buffer, amplitude for waveform
├── TranscriptionService/   # Core ML model load, ANE inference, transcript extraction
├── PasteService/           # Clipboard save/restore, CGEvent Cmd-V
├── ModelManager/           # Download, checksum, storage, update checks
└── UI/
    ├── HUD/                # NSPanel floating waveform overlay
    ├── Settings/           # SwiftUI Settings panel
    └── Onboarding/         # SwiftUI first-launch flow
```

---

## 6. Build Plan

### 6.1 Milestones

| Milestone | Scope | Estimate |
|---|---|---|
| M0 — Model conversion | One-time dev step: convert Parakeet TDT v3 to `.mlpackage`, validate ANE routing, confirm < 1s latency on target machine | 1–2 days |
| M1 — Skeleton | Xcode project, menu bar icon, global hotkey fires console log, AVAudioEngine captures to buffer, Core ML inference prints transcript | 1 day |
| M2 — Core loop | Full push-to-talk end-to-end: hotkey → capture → ANE inference → paste. Clipboard save/restore working. No HUD yet. | 1 day |
| M3 — HUD & polish | Floating HUD with waveform and timer. Menu bar icon state changes. Empty audio guard. Error fallback. | 1 day |
| M4 — Onboarding | First-launch wizard: model download with progress, mic permission, accessibility permission detection | 1 day |
| M5 — Settings | Settings panel: rebindable hotkey, launch at login, sound feedback toggle | 1 day |
| M6 — Distribution | DMG packaging, code signing (Developer ID), notarization, Gatekeeper pass | 1 day |

**Total estimate: ~7–9 days**

### 6.2 Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Core ML conversion produces degraded accuracy | Medium | Validate thoroughly at M0 before writing any app code. Fallback: use parakeet.cpp with a local HTTP server and `URLSession` from Swift. |
| ANE routing falls back to CPU silently | Medium | Confirm ANE is being used via `Instruments → Core ML` profiling during M0 spike. `computeUnits: .cpuAndNeuralEngine` is required — not `.all` which may route to GPU. |
| Accessibility permission breaks on macOS update | Low | Well-established API. Test on each macOS release. |
| Hotkey conflicts with system shortcuts | Low | § / backtick is rarely bound system-wide. Configurable hotkey resolves any conflict. |
| Model download reliability on first launch | Low | Resumable download via `URLSession` background session with checksum verification. |

### 6.3 Dependencies

| Dependency | Purpose |
|---|---|
| Xcode 15+ | IDE and Swift compiler |
| Python 3.10 + NeMo + coremltools | One-time model conversion (developer only — not a runtime dependency) |
| Hugging Face Hub CLI | Model download during conversion |
| KeyboardShortcuts (SPM) | Optional — cleaner global hotkey management |
| create-dmg | DMG packaging |
| Apple Developer account | Code signing + notarization |

---

## 7. UX & Design Specification

### 7.1 Design Principles

- **Invisible when idle** — the app should not draw attention to itself when not recording
- **No decisions during recording** — the interaction is purely physical (hold/release)
- **Forgiveness** — a short accidental press produces no output and no error
- **Speed over features** — latency is the primary quality metric

### 7.2 HUD Specification

| Property | Spec |
|---|---|
| Shape | Rounded rectangle pill, ~280pt wide × 48pt tall |
| Position | Bottom-center of main screen, 32pt from bottom edge |
| Background | Ultra-thin material (`NSVisualEffectView`) — adapts to light/dark mode |
| Waveform | 20 vertical bars updated at 30Hz from audio tap amplitude |
| Timer | Right-aligned, SF Mono, elapsed seconds to one decimal (e.g. "7.3s") |
| Accent color | Orange (#E07B39) |
| Window level | `NSWindowLevel.floating + 1` |
| Dismiss | Instant on hotkey release — no animation |

### 7.3 Menu Bar Icon States

| State | Icon |
|---|---|
| Idle | `mic.fill` SF Symbol, template rendering |
| Recording | `mic.fill` with orange pulse badge |
| Error | `mic.slash.fill` shown for 3 seconds, then returns to idle |

---

## 8. Out of Scope & Future Considerations

### 8.1 Explicitly Out of Scope for v1.0

- Streaming real-time transcription
- iOS or iPadOS version
- App Store distribution
- Windows or Linux
- Speaker diarization
- Translation

### 8.2 Potential v1.1+ Features

- Streaming inference with real-time display in HUD (WhisperLiveKit-style chunked processing)
- Personal vocabulary — custom dictionary for names and technical terms
- Post-processing LLM pass — optional local model (via Ollama) to clean filler words and reformat
- Transcription history panel with search
- Custom backend swap — point to any OpenAI-API-compatible local server (e.g. whisper-server on homelab)
- iOS companion app using homelab backend

---

## 9. Acceptance Criteria

| ID | Area | Criterion |
|---|---|---|
| AC-01 | Core loop | Hold hotkey → speak 10s → release → transcript pastes in TextEdit within 1 second |
| AC-02 | Accuracy | Word error rate < 10% on 20 test utterances of conversational English in a quiet environment |
| AC-03 | ANE routing | Instruments → Core ML profiler confirms Neural Engine is handling inference, not CPU fallback |
| AC-04 | Privacy | Little Snitch confirms zero outbound network during normal operation after model download |
| AC-05 | Clipboard | Clipboard contents before dictation are identical to contents 2 seconds after paste |
| AC-06 | Footprint | Activity Monitor shows < 500 MB RSS and < 1% CPU while app is idle |
| AC-07 | Onboarding | Fresh install completes onboarding without Terminal or manual file placement |
| AC-08 | Gatekeeper | DMG passes Gatekeeper on default security settings — no "unidentified developer" warning |
| AC-09 | Stability | 10 rapid hotkey press/release cycles in 5 seconds produce no crash and leave app in clean idle state |
| AC-10 | Hotkey rebind | Changed hotkey persists across quit/relaunch with no reconfiguration |
| AC-11 | Launch at login | Enable toggle → reboot → VoiceDrop running before user opens any other app |
