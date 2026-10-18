import SwiftUI

// ✦ "Northstar is thinking…" — shown where the reply will appear, on the left just above the ask bar.
// The star rocks 25° left, back to center, 25° right, while soft light rays pulse around it.
// Beside it, calm progress words change slowly (every 2.5 s, a gentle fade): "Exploring possibilities…",
// "Finding connections…". Honest and general; it never names an expert it hasn't picked yet.
// With Reduce Motion on, the star stays still, only the rays glow, and the words stay on one line.

struct NorthstarThinkingStar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rock = false
    @State private var glow = false
    @State private var step = 0

    static let phrases = [
        "Exploring possibilities…",
        "Finding connections…",
        "Identifying patterns…",
        "Considering your goals…",
        "Looking for the clearest path…",
    ]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                rays
                NorthstarStarShape()
                    .fill(NorthstarChatStyle.starGold)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (rock ? 25 : -25)))
                    .shadow(color: NorthstarChatStyle.starGold.opacity(glow ? 0.7 : 0.2), radius: glow ? 8 : 3)
            }
            .frame(width: 40, height: 40)

            Text(Self.phrases[step % Self.phrases.count])
                .font(.callout)
                .foregroundStyle(NorthstarChatStyle.label)
                .opacity(glow ? 1 : 0.65)
                .id(step)
                .transition(.opacity)
            Spacer()
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Northstar is thinking")
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { rock = true }
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.6)) { step += 1 }
            }
        }
    }

    /// Eight thin rays around the star that brighten and stretch together.
    private var rays: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(NorthstarChatStyle.starGold)
                    .frame(width: 1.5, height: i.isMultiple(of: 2) ? 7 : 4)
                    .offset(y: glow ? -17 : -13)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .opacity(glow ? 0.75 : 0.15)
    }
}

#Preview {
    NorthstarThinkingStar().padding().background(NorthstarChatStyle.background)
}
