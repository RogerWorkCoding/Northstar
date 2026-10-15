import SwiftUI

// "Show options instead of asking": when someone isn't sure what they want,
// Northstar offers three very different directions to react to. Each card has
// a name, colors, a type sample and a few words. Tap "Choose this" to go on.

struct DirectionsView: View {
    let directions: [NorthstarInsight.Direction]
    /// Read from the chat, so it's always true to what was sent.
    var chosenName: String? = nil
    var canChoose: Bool = true
    var onChoose: (NorthstarInsight.Direction) -> Void = { _ in }

    private var locked: Bool { chosenName != nil || !canChoose }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption.weight(.semibold))
                Text("THREE DIRECTIONS")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
            }
            .foregroundStyle(NorthstarChatStyle.label)

            ForEach(directions, id: \.self) { direction in
                card(direction)
            }
        }
    }

    private func card(_ d: NorthstarInsight.Direction) -> some View {
        let isChosen = chosenName == d.name
        let dimmed = locked && !isChosen
        return VStack(alignment: .leading, spacing: 12) {
            Text(d.name)
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.text)

            HStack(spacing: 8) {
                ForEach(Array(d.palette.enumerated()), id: \.offset) { _, hex in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: hex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1)
                        )
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Colors: " + d.palette.map(Color.spokenName(hex:)).joined(separator: ", "))

            Text("Aa  \(d.name)")
                .font(d.sampleFont)
                .foregroundStyle(NorthstarChatStyle.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)

            Text(d.mood)
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)

            if !d.keywords.isEmpty {
                Text(d.keywords.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
            }

            Button {
                guard !locked else { return }
                onChoose(d)
            } label: {
                Text(isChosen ? "Chosen ✓" : "Choose this")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isChosen ? NorthstarChatStyle.text : NorthstarChatStyle.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule().fill(isChosen
                            ? NorthstarChatStyle.savedGreen.opacity(0.25)
                            : NorthstarChatStyle.primaryFill)
                    )
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .opacity(dimmed ? 0.4 : 1)
            .accessibilityLabel(isChosen ? "\(d.name), chosen" : "Choose \(d.name)")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isChosen ? NorthstarChatStyle.savedGreen : NorthstarChatStyle.stroke, lineWidth: isChosen ? 2 : 1)
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
    /// A plain spoken name for a color, for VoiceOver ("dark blue", "light gold").
    static func spokenName(hex: String) -> String {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255, g = Double((v >> 8) & 0xFF) / 255, b = Double(v & 0xFF) / 255
        let maxC = max(r, g, b), minC = min(r, g, b), light = (maxC + minC) / 2
        let tone = light > 0.8 ? "light " : light < 0.25 ? "dark " : ""
        if maxC - minC < 0.12 { return light > 0.9 ? "white" : light < 0.1 ? "black" : tone + "gray" }
        var hue: Double
        if maxC == r { hue = (g - b) / (maxC - minC) } else if maxC == g { hue = 2 + (b - r) / (maxC - minC) } else { hue = 4 + (r - g) / (maxC - minC) }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360); if hue < 0 { hue += 360 }
        let names: [(Double, String)] = [(15, "red"), (45, "orange"), (65, "gold"), (160, "green"), (200, "teal"), (255, "blue"), (290, "purple"), (335, "pink"), (360, "red")]
        let name = names.first { hue < $0.0 }?.1 ?? "red"
        return tone + name
    }

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
