import AppKit
import ApplicationServices
import CoreGraphics
import os

@MainActor
final class PasteService {
    func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Logger.app.notice("Wrote to clipboard (\(text.count, privacy: .public) chars)")

        guard ensureAccessibility() else {
            Logger.app.notice("Accessibility not granted — transcript is in clipboard, press ⌘V to paste")
            return
        }

        postCmdV()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let prev = previous { pasteboard.setString(prev, forType: .string) }
        }
    }

    // Returns true if Accessibility is trusted. If not, shows the system prompt
    // that adds VoiceDrop to System Settings → Privacy & Security → Accessibility.
    private func ensureAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        return false
    }

    private func postCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        Logger.app.notice("CGEvent Cmd-V posted")
    }
}
