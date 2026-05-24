import AppKit

@MainActor
final class HotkeyManager {
    var onRecordingStart: (() -> Void)?
    var onRecordingEnd: (() -> Void)?

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var isRecording = false

    // kVK_ISO_Section (0x0A = 10): § on ISO/UK keyboards, same physical position as ` on ANSI/US (kVK_ANSI_Grave = 0x32 = 50)
    var hotKeyCode: UInt16 = 10

    func start() {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == self.hotKeyCode, !self.isRecording else { return }
            self.isRecording = true
            self.onRecordingStart?()
        }
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self, event.keyCode == self.hotKeyCode, self.isRecording else { return }
            self.isRecording = false
            self.onRecordingEnd?()
        }
    }

    func stop() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m) }
        keyDownMonitor = nil
        keyUpMonitor = nil
        isRecording = false
    }
}
