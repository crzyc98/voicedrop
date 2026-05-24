import AppKit
import SwiftUI

@MainActor
final class RecordingHUDController {
    private var panel: NSPanel?
    private let state: RecordingState

    init(state: RecordingState) {
        self.state = state
    }

    func show() {
        if panel == nil {
            panel = buildPanel()
        }
        position()
        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func position() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = screen.frame.midX - 140
        let y = screen.frame.minY + 32
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func buildPanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hasShadow = true

        let vfx = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 280, height: 48))
        vfx.material = .hudWindow
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 24
        vfx.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: RecordingHUDView(state: state))
        hosting.frame = vfx.bounds
        hosting.autoresizingMask = [.width, .height]
        vfx.addSubview(hosting)

        p.contentView = vfx
        return p
    }
}
