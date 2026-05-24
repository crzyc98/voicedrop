import SwiftUI

@Observable
final class RecordingState {
    var amplitudeBars: [Float] = Array(repeating: 0.1, count: 20)
    var startDate: Date = .now

    var elapsedTime: Double {
        Date.now.timeIntervalSince(startDate)
    }
}
