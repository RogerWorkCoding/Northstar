import SwiftUI

// ✦ "Northstar is thinking…" — shown where the reply will appear, on the left just above the ask bar.
// The star rocks 25° left, back to center, 25° right, while soft light rays pulse around it.
// With Reduce Motion on, the star stays still and only the rays glow.

struct NorthstarThinkingStar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rock = false
    @State private var glow = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                rays
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(NorthstarChatStyle.starGold)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (rock ? 25 : -25)))
                    .shadow(color: NorthstarChatStyle.starGold.opacity(glow ? 0.7 : 0.2), radius: glow ? 8 : 3)
            }
            .frame(width: 40, height: 40)

            Text("Northstar is thinking…")
                .font(.callout)
                .foregroundStyle(NorthstarChatStyle.label)
                .opacity(glow ? 1 : 0.65)
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
