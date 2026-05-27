import SwiftUI

struct RecordingHUDView: View {
    var state: RecordingState

    private static let orange = Color(red: 0.878, green: 0.482, blue: 0.224)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            HStack(spacing: 0) {
                waveform
                Spacer()
                timerLabel
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 280, height: 48)
        .background(.clear)
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(state.amplitudeBars.enumerated()), id: \.offset) { _, amp in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.orange)
                    .frame(width: 8, height: max(4, CGFloat(amp) * 32))
                    .animation(.linear(duration: 0.033), value: amp)
            }
        }
    }

    private var timerLabel: some View {
        Text(String(format: "%.1fs", max(0, state.elapsedTime)))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
    }
}
