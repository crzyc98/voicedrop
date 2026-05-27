# VoiceDrop

VoiceDrop is a lightweight macOS menu bar app for push-to-talk dictation. Hold a hotkey, speak, release — the transcript pastes at your cursor.

## Features
- **Privacy First:** All inference runs locally on-device. Audio is never written to disk or sent to a server.
- **Dual Engine:** NVIDIA Parakeet TDT 0.6B v3 via Core ML (ANE-accelerated) or Apple Speech Recognition (no download required).
- **Low Latency:** Optimized for Apple's Neural Engine via FluidAudio.
- **Simple Workflow:** Hold `` ` `` (backtick), speak, release to paste.
- **Onboarding:** First-launch flow walks through mic + speech permissions.
- **Settings:** Launch at login, sound feedback, diagnostic report, and log viewer.
- **Clipboard Safety:** Previous clipboard contents are restored after paste.

## Requirements
- macOS 14+, Apple Silicon

## Build
- Open in VS Code with the SweetPad extension
- **SweetPad: Build & Run** → target `macOS arm64 Debug`
- Distribution: direct DMG (no App Store)

> **Before building:** open `voicedrop.xcodeproj/project.pbxproj` and replace `KR953WG4K5` with your own Apple Developer Team ID. You can find yours at [developer.apple.com/account](https://developer.apple.com/account) under Membership. Also update `PRODUCT_BUNDLE_IDENTIFIER` (`crzyc.voicedrop`) to your own reverse-domain identifier.

## License
MIT — see [LICENSE](LICENSE).

See [VoiceDrop_PRD.md](VoiceDrop_PRD.md) for full product requirements.
