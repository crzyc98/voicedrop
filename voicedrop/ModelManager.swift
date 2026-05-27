import AVFoundation
import FluidAudio
import os

@Observable
@MainActor
final class ParakeetManager {
    static let shared = ParakeetManager()

    // Bump compiledModelVersion when upgrading to a new model enum (e.g. .v4).
    // cleanupStaleModelIfNeeded() will auto-delete cached files from the old version.
    static let compiledModelVersion = "v3"
    private static let pinnedFluidAudioVersion = "0.14.7"

    enum State: Equatable {
        case notReady, downloading, loading, ready
        case failed(String)
    }

    enum UpdateCheckState: Equatable {
        case idle, checking, upToDate, available(String), failed
    }

    var state: State = .notReady
    var progress: Double = 0
    var updateCheckState: UpdateCheckState = .idle

    private var asr: AsrManager?

    var isModelDownloaded: Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory())
    }

    var isReady: Bool { state == .ready }

    var installedVersion: String? {
        UserDefaults.standard.string(forKey: "installedParakeetVersion")
    }

    func prepare() async {
        switch state {
        case .ready, .downloading, .loading: return
        default: break
        }

        cleanupStaleModelIfNeeded()

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
            markInstalled()
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

    // Queries FluidAudio's GitHub releases. If a newer release exists the user
    // needs a new VoiceDrop build — model version enum cases are compile-time.
    func checkForUpdates() async {
        guard updateCheckState != .checking else { return }
        updateCheckState = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/FluidInference/FluidAudio/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("VoiceDrop/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Release: Decodable { let tag_name: String }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latestTag = release.tag_name
            let latestVersion = latestTag.hasPrefix("v") ? String(latestTag.dropFirst()) : latestTag
            updateCheckState = latestVersion == Self.pinnedFluidAudioVersion ? .upToDate : .available(latestTag)
        } catch {
            Logger.app.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            updateCheckState = .failed
        }
    }

    // Deletes the cached model if a different version was previously installed.
    // Called at the start of prepare() so stale files never block a fresh download.
    private func cleanupStaleModelIfNeeded() {
        guard let installed = installedVersion, installed != Self.compiledModelVersion else { return }
        let dir = AsrModels.defaultCacheDirectory()
        try? FileManager.default.removeItem(at: dir)
        UserDefaults.standard.removeObject(forKey: "installedParakeetVersion")
        Logger.app.notice("Removed stale Parakeet model: \(installed, privacy: .public)")
    }

    private func markInstalled() {
        UserDefaults.standard.set(Self.compiledModelVersion, forKey: "installedParakeetVersion")
    }
}
