import SwiftUI

// "Show options instead of asking": when someone isn't sure what they want,
// Northstar offers three very different directions to react to. Each card has
// a name, colors, a type sample and a few words. Tap "Choose this" to go on.

struct DirectionsView: View {
    let directions: [NorthstarInsight.Direction]
    var onChoose: (NorthstarInsight.Direction) -> Void = { _ in }

    @State private var chosen: NorthstarInsight.Direction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                Text("THREE DIRECTIONS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
            }
            .foregroundStyle(NorthstarChatStyle.label)

            ForEach(directions, id: \.self) { direction in
                card(direction)
            }
        }
    }

    private func card(_ d: NorthstarInsight.Direction) -> some View {
        let isChosen = chosen == d
        return VStack(alignment: .leading, spacing: 12) {
            Text(d.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(Array(d.palette.enumerated()), id: \.offset) { _, hex in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: hex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .accessibilityHidden(true)

            Text("Aa  \(d.name)")
                .font(d.sampleFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)

            Text(d.mood)
                .font(.system(size: 15))
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)

            if !d.keywords.isEmpty {
                Text(d.keywords.joined(separator: " · "))
                    .font(.system(size: 14))
                    .foregroundStyle(NorthstarChatStyle.label)
            }

            Button {
                guard chosen == nil else { return }
                withAnimation(.easeOut(duration: 0.2)) { chosen = d }
                onChoose(d)
            } label: {
                Text(isChosen ? "Chosen ✓" : "Choose this")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isChosen ? .white : Color(red: 0.05, green: 0.09, blue: 0.21))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule().fill(isChosen
                            ? Color(red: 0.56, green: 0.90, blue: 0.75).opacity(0.25)
                            : Color(red: 0.91, green: 0.93, blue: 1.0))
                    )
            }
            .buttonStyle(.plain)
            .disabled(chosen != nil && !isChosen)
            .opacity(chosen != nil && !isChosen ? 0.4 : 1)
            .accessibilityLabel(isChosen ? "\(d.name), chosen" : "Choose \(d.name)")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(isChosen ? 0.5 : 0.18), lineWidth: isChosen ? 2 : 1)
        )
        .accessibilityElement(children: .contain)
    }
}

extension NorthstarInsight.Direction {
    /// The type sample, drawn in this direction's type style.
    var sampleFont: Font {
        switch typeStyle {
        case "serif": return .system(size: 28, weight: .regular, design: .serif)
        case "rounded": return .system(size: 28, weight: .semibold, design: .rounded)
        case "mono": return .system(size: 26, weight: .regular, design: .monospaced)
        case "script": return .custom("Snell Roundhand", size: 30)
        default: return .system(size: 28, weight: .medium)
        }
    }
}

extension Color {
    /// Color from "#RRGGBB" (the brain only sends this format).
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(clean, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
