import SwiftUI

// Temporary design prototype only — not wired into NorthstarApp's navigation.
// Built on the real NorthstarVisionLandscape artwork rather than a procedurally
// drawn mountain silhouette; the landscape is the hero, everything else is quiet.
struct NorthstarVisionScreen: View {
    var body: some View {
        ZStack {
            NorthstarVisionLandscapeBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                NorthstarVisionStarMark()
                    .accessibilityHidden(true)

                Spacer(minLength: 20)

                Text("Northstar")
                    .font(.system(size: 32, weight: .light))
                    .tracking(6)
                    .foregroundStyle(NorthstarResponseTheme.warmWhite)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 12)

                VStack(spacing: 3) {
                    Text("One clear destination.")
                    Text("An intelligent path forward.")
                }
                .font(.system(size: 13, weight: .regular))
                .tracking(0.4)
                .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.65))
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 30)

                NorthstarVisionPrincipleRow()

                Spacer()

                NorthstarVisionComposer()
                    .padding(.horizontal, 22)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 28)
        }
    }
}

/// Deliberately bottom-anchored (not the default center-cropped scaledToFill), so
/// the mountains/valley stay fully intact at the screen's bottom even if a device's
/// aspect ratio differs slightly from the artwork's — any overflow crops away excess
/// sky at the top instead of eating into the landscape. The asset is naturally dark,
/// so a restrained brightness/contrast lift plus a small, localized cool-blue radial
/// glow centered on the valley make the layered ridges read clearly without washing
/// out the rest of the sky.
private struct NorthstarVisionLandscapeBackground: View {
    var body: some View {
        ZStack {
            Image("NorthstarVisionLandscape")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .clipped()
                .brightness(0.045)
                .contrast(1.15)
                .saturation(1.05)

            RadialGradient(
                colors: [Color(red: 0.55, green: 0.68, blue: 0.86).opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 10,
                endRadius: 260
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

/// A soft white-to-cool-blue glow, restrained and focused rather than diffuse —
/// deliberately not gold, so it harmonizes with the photographed night sky
/// instead of competing with it.
private struct NorthstarVisionStarMark: View {
    var body: some View {
        ZStack {
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(Color(red: 0.62, green: 0.74, blue: 0.92))
                .blur(radius: 22)
                .opacity(0.4)

            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(
                    LinearGradient(
                        colors: [NorthstarResponseTheme.warmWhite, Color(red: 0.72, green: 0.82, blue: 0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 0.6, green: 0.72, blue: 0.9).opacity(0.5), radius: 12)
        }
    }
}

/// The four principles as a quiet, evenly sized 2x2 grid — a fixed grid (rather
/// than one shrink-to-fit line) is what keeps every word at the same size on
/// every device width, instead of minimumScaleFactor shrinking words unevenly.
private struct NorthstarVisionPrincipleRow: View {
    private let topRow = ["Reflect", "Perspective"]
    private let bottomRow = ["Clarity", "Progress"]

    var body: some View {
        VStack(spacing: 8) {
            principleLine(topRow)
            principleLine(bottomRow)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core principles: Reflect, Perspective, Clarity, Progress")
    }

    private func principleLine(_ words: [String]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.5))

                if index < words.count - 1 {
                    Text("·")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.3))
                }
            }
        }
    }
}

/// A restrained, translucent composer — secondary to the landscape and brand,
/// not a bright floating card. Non-functional; this screen is a visual
/// prototype only, so there is no send action or view-model wiring.
private struct NorthstarVisionComposer: View {
    @State private var draftText = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.6))

            TextField(
                "",
                text: $draftText,
                prompt: Text("Ask anything")
                    .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.4))
            )
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.85))

            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.5))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(.ultraThinMaterial).opacity(0.55))
        .overlay(Capsule().strokeBorder(NorthstarResponseTheme.warmWhite.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message composer, ask anything")
    }
}

#Preview("Northstar Vision Screen") {
    NorthstarVisionScreen()
}
