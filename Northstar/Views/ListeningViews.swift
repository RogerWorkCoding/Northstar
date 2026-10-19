import SwiftUI

// 🎙 Shows that Northstar is listening: live voice bars that move with their voice, and a soft pulsing ring
// around the stop button. Says "Listening", not "Recording": speech turns into text on the phone and only the
// text is sent; no audio is kept.

/// Little bars that rise and fall with the speaker's voice (newest on the right).
struct VoiceBars: View {
    var level: Float
    var color: Color = Color(red: 1.0, green: 0.84, blue: 0.55)
    var count = 14

    @State private var history: [CGFloat] = []

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(padded.enumerated()), id: \.offset) { _, v in
                Capsule()
                    .fill(color.opacity(0.35 + 0.65 * Double(v)))
                    .frame(width: 3, height: 4 + 18 * v)
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.12), value: history)
        .onChange(of: level) {
            history.append(CGFloat(level))
            if history.count > count { history.removeFirst(history.count - count) }
        }
        .accessibilityHidden(true)
    }

    private var padded: [CGFloat] {
        Array(repeating: 0, count: max(0, count - history.count)) + history
    }
}

/// A soft ring that breathes around a button while listening. Still (just shown) with Reduce Motion.
struct ListeningRing: View {
    var active: Bool
    var color: Color = Color(red: 1.0, green: 0.84, blue: 0.55)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grow = false

    var body: some View {
        Circle()
            .stroke(color.opacity(active ? (grow ? 0.0 : 0.8) : 0), lineWidth: 2)
            .scaleEffect(grow ? 1.6 : 1.0)
            .onChange(of: active, initial: true) {
                grow = false
                guard active, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { grow = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
