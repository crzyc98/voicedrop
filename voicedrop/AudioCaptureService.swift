import AVFoundation

// Accumulates raw PCM frames and tracks latest RMS amplitude.
// Accessed from both main thread and the audio I/O thread — protected by NSLock.
private final class SampleAccumulator: @unchecked Sendable {
    private var frames: [Float] = []
    private var captureFormat: AVAudioFormat?
    private(set) var latestAmplitude: Float = 0
    private let lock = NSLock()

    func configure(format: AVAudioFormat) {
        lock.withLock {
            captureFormat = format
            frames = []
            latestAmplitude = 0
        }
    }

    func addBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        let newFrames = Array(UnsafeBufferPointer(start: data, count: frameCount))
        let rms = sqrt(newFrames.reduce(Float(0)) { $0 + $1 * $1 } / Float(frameCount))
        lock.withLock {
            frames.append(contentsOf: newFrames)
            latestAmplitude = min(rms * 4, 1.0)
        }
    }

    // Returns accumulated audio as a mono Float32 buffer and its duration.
    // Resets internal state — safe to call once per recording.
    func consume() -> (buffer: AVAudioPCMBuffer?, duration: Double) {
        lock.withLock {
            defer {
                frames = []
                captureFormat = nil
                latestAmplitude = 0
            }
            guard let format = captureFormat, !frames.isEmpty else { return (nil, 0) }
            let duration = Double(frames.count) / format.sampleRate
            let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: format.sampleRate,
                channels: 1,
                interleaved: false
            )!
            guard let pcm = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(frames.count)),
                  let channelData = pcm.floatChannelData?[0] else { return (nil, duration) }
            pcm.frameLength = AVAudioFrameCount(frames.count)
            frames.withUnsafeBufferPointer { channelData.update(from: $0.baseAddress!, count: frames.count) }
            return (pcm, duration)
        }
    }
}

@MainActor
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let accumulator = SampleAccumulator()

    var currentAmplitude: Float { accumulator.latestAmplitude }

    func startCapture() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        accumulator.configure(format: format)
        let acc = accumulator
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            acc.addBuffer(buffer)
        }
        try engine.start()
    }

    func stopCapture() -> (buffer: AVAudioPCMBuffer?, duration: Double) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return accumulator.consume()
    }
}
