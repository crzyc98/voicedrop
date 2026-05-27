import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let manager: OnboardingManager

    init(manager: OnboardingManager) {
        self.manager = manager
    }

    func show() {
        if window == nil {
            window = buildWindow()
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }

    // Quit the app if the user closes the window before finishing onboarding.
    func windowWillClose(_ notification: Notification) {
        if !manager.isComplete {
            NSApp.terminate(nil)
        }
    }

    private func buildWindow() -> NSWindow {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Welcome to VoiceDrop"
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.contentView = NSHostingView(rootView: OnboardingView(manager: manager))
        return w
    }
}
