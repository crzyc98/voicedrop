import AVFoundation
import FluidAudio
import os

@Observable
@MainActor
final class ParakeetManager {
    static let shared = ParakeetManager()

    enum State: Equatable {
        case notReady, downloading, loading, ready
        case failed(String)
    }

    var state: State = .notReady
    var progress: Double = 0

    private var asr: AsrManager?

    var isModelDownloaded: Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory())
    }

    var isReady: Bool { state == .ready }

    // Downloads (if needed) and loads the Parakeet TDT v3 Core ML models.
    func prepare() async {
        switch state {
        case .ready, .downloading, .loading: return
        default: break
        }

        progress = 0
        state = isModelDownloaded ? .loading : .downloading

        do {
            let models = try await AsrModels.downloadAndLoad(version: .v3) { p in
                Task { @MainActor in
                    let mgr = ParakeetManager.shared
                    mgr.progress = p.fractionCompleted
                    if mgr.state == .downloading, p.fractionCompleted >= 1.0 {
                        mgr.state = .loading
                    }
                }
            }
            state = .loading
            let manager = AsrManager()
            try await manager.loadModels(models)
            asr = manager
            state = .ready
        } catch {
            Logger.app.error("Parakeet load error: \(error.localizedDescription, privacy: .public)")
            asr = nil
            state = .failed(error.localizedDescription)
        }
    }

    func transcribe(_ buffer: AVAudioPCMBuffer) async -> String {
        guard let asr else { return "" }
        do {
            var decoderState = try TdtDecoderState()
            let result = try await asr.transcribe(buffer, decoderState: &decoderState)
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Logger.app.error("Parakeet transcribe error: \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }
}
