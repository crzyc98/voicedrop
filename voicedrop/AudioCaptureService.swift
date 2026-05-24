import AVFoundation

// Accumulates sample count and tracks latest RMS amplitude.
// Accessed from both main thread and the audio I/O thread — protected by NSLock.
private final class SampleAccumulator: @unchecked Sendable {
    private var count: Int = 0
    private var sampleRate: Double = 48_000
    private(set) var latestAmplitude: Float = 0
    private let lock = NSLock()

    func configure(sampleRate: Double) {
        lock.withLock {
            self.sampleRate = sampleRate
            self.count = 0
            self.latestAmplitude = 0
        }
    }

    func addBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        let frames = UnsafeBufferPointer(start: data, count: frameCount)
        let sumOfSquares = frames.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(frameCount))
        lock.withLock {
            self.count += frameCount
            self.latestAmplitude = min(rms * 4, 1.0)
        }
    }

    func consume() -> Double {
        lock.withLock {
            let duration = Double(count) / sampleRate
            count = 0
            latestAmplitude = 0
            return duration
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
        accumulator.configure(sampleRate: format.sampleRate)

        let acc = accumulator
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            acc.addBuffer(buffer)
        }

        try engine.start()
    }

    func stopCapture() -> Double {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return accumulator.consume()
    }
}
