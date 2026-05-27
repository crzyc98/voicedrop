import AppKit

@MainActor
final class HotkeyManager {
    var onRecordingStart: (() -> Void)?
    var onRecordingEnd: (() -> Void)?

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var isRecording = false

    var hotKeyCode: UInt16 = 50  // kVK_ANSI_Grave — set from AppSettings on launch

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
