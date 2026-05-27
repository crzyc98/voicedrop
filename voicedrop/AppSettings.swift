import Foundation
import ServiceManagement
import os

enum TranscriptionEngine: String, CaseIterable, Identifiable {
    case parakeet, appleSpeech
    var id: String { rawValue }
    var label: String {
        switch self {
        case .parakeet: return "Parakeet TDT v3"
        case .appleSpeech: return "Apple Speech"
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var hotKeyCode: UInt16 = 50 {
        didSet { UserDefaults.standard.set(Int(hotKeyCode), forKey: "hotKeyCode") }
    }
    var transcriptionEngine: TranscriptionEngine = .parakeet {
        didSet { UserDefaults.standard.set(transcriptionEngine.rawValue, forKey: "transcriptionEngine") }
    }
    var soundFeedbackEnabled: Bool = false {
        didSet { UserDefaults.standard.set(soundFeedbackEnabled, forKey: "soundFeedback") }
    }
    var transcriptionHistoryEnabled: Bool = false {
        didSet { UserDefaults.standard.set(transcriptionHistoryEnabled, forKey: "transcriptionHistory") }
    }
    var launchAtLogin: Bool = false {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                Logger.app.error("Launch at login error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    init() {
        let code = UserDefaults.standard.integer(forKey: "hotKeyCode")
        // 0 = never set, 10 = old ISO default (§) — both migrate to backtick on US keyboards
        hotKeyCode = (code > 0 && code != 10) ? UInt16(code) : 50
        transcriptionEngine = TranscriptionEngine(
            rawValue: UserDefaults.standard.string(forKey: "transcriptionEngine") ?? "") ?? .parakeet
        soundFeedbackEnabled = UserDefaults.standard.bool(forKey: "soundFeedback")
        transcriptionHistoryEnabled = UserDefaults.standard.bool(forKey: "transcriptionHistory")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
