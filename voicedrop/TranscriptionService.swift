import AVFoundation
import Speech
import os

// Transcribes a complete recorded clip in one shot (batch).
final class AppleSpeechTranscriber {
    func transcribe(_ buffer: AVAudioPCMBuffer) async -> String {
        let recognizer = SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { return "" }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.append(buffer)
        request.endAudio()

        return await withCheckedContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let result, result.isFinal {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error {
                    Logger.app.error("Apple Speech error: \(error.localizedDescription, privacy: .public)")
                    resumed = true
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
