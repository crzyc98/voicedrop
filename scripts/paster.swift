import ApplicationServices
import CoreGraphics
import Foundation

// Check if accessibility access is granted to this helper.
// If not, it will prompt the user when run.
let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)

if !trusted {
    print("Accessibility access not granted. Please grant access in System Settings -> Privacy & Security -> Accessibility.")
    exit(1)
}

guard let src = CGEventSource(stateID: .hidSystemState) else {
    print("Failed to create CGEventSource")
    exit(1)
}

guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
      let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) else {
    print("Failed to create CGEvents")
    exit(1)
}

down.flags = .maskCommand
up.flags = .maskCommand

down.post(tap: .cgAnnotatedSessionEventTap)
up.post(tap: .cgAnnotatedSessionEventTap)

print("Cmd-V posted successfully.")
