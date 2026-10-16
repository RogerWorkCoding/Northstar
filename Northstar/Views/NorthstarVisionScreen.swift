import SwiftUI

// Arrival screen: the landscape + star + wordmark are the hero, with a lightweight
// functional composer at the bottom whose only job is to capture first intent and
// hand it to NorthstarRootView — all real chat behavior (send pipeline, star menu,
// microphone) lives in ContentView, untouched.
struct NorthstarVisionScreen: View {
    let onSubmitPrompt: (String) -> Void
    let onSelectStar: () -> Void
    let onSelectMicrophone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWelcomeMessageVisible = true

    /// A single message today; kept as an array (not a plain String) so rotating
    /// through several welcome messages later only means picking a different
    /// index here, not changing how the view displays or fades the text.
    private static let welcomeMessages: [String] = [
        "One clear destination.\nAn intelligent path forward."
    ]

    private var welcomeMessageLines: [String] {
        (Self.welcomeMessages.first ?? "").components(separatedBy: "\n")
    }

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
                    ForEach(welcomeMessageLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.system(size: 13, weight: .regular))
                .tracking(0.4)
                .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.65))
                .multilineTextAlignment(.center)
                .opacity(isWelcomeMessageVisible ? 1 : 0)
                .accessibilityElement(children: .combine)
                .accessibilityHidden(!isWelcomeMessageVisible)

                Spacer()

                NorthstarVisionComposer(
                    onSubmitPrompt: onSubmitPrompt,
                    onSelectStar: onSelectStar,
                    onSelectMicrophone: onSelectMicrophone
                )
                .padding(.horizontal, 22)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 28)
        }
        .task {
            try? await Task.sleep(for: .seconds(2.75))
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.6)) {
                isWelcomeMessageVisible = false
            }
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
struct NorthstarVisionLandscapeBackground: View {
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
/// instead of competing with it. Purely decorative (the functional star control
/// lives in the composer below, mirroring ContentView's sparkle menu button).
/// `size` parametrizes the crisp star's diameter so this same mark can be
/// reused at different scales (e.g. ContentView's empty-state hero).
struct NorthstarVisionStarMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            // The faint ring, only where there's room for it.
            if size >= 36 {
                Circle()
                    .stroke(Color(red: 0.66, green: 0.76, blue: 0.93).opacity(0.3), lineWidth: max(0.5, size * 0.012))
                    .frame(width: size * 0.7, height: size * 0.7)
            }
            // Soft blue glow around the star.
            NorthstarStarShape()
                .fill(Color(red: 0.66, green: 0.78, blue: 1.0))
                .frame(width: size, height: size)
                .blur(radius: size * 0.04)
                .opacity(0.9)
            // The star: four slim points, the vertical ones a little longer.
            NorthstarStarShape()
                .fill(LinearGradient(colors: [.white, Color(red: 0.83, green: 0.88, blue: 0.97)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)
            // Warm light at the center.
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.99, blue: 0.95),
                                              Color(red: 1, green: 0.95, blue: 0.8).opacity(0.85),
                                              Color(red: 0.56, green: 0.69, blue: 0.93).opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.15))
                .frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}

/// The Northstar star: four slim, curved points (vertical slightly longer), as a vector so it's sharp at any size.
struct NorthstarStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * r, y: c.y + y * r) }
        let a: CGFloat = 0.006, b: CGFloat = 0.09
        let top: CGFloat = -0.97, bottom: CGFloat = 1.0, side: CGFloat = 0.83
        var path = Path()
        path.move(to: p(0, top))
        path.addCurve(to: p(side, 0), control1: p(a, -b), control2: p(b, -a))
        path.addCurve(to: p(0, bottom), control1: p(b, a), control2: p(a, b))
        path.addCurve(to: p(-side, 0), control1: p(-a, b), control2: p(-b, a))
        path.addCurve(to: p(0, top), control1: p(-b, -a), control2: p(-a, -b))
        path.closeSubpath()
        return path
    }
}

/// A lightweight, locally-owned composer — not extracted from or shared with
/// ContentView's promptArea (that stays untouched per the approved low-risk plan).
/// Its only responsibility is to capture the first prompt/star/mic intent and
/// report it upward; it does not call Gemini, append messages, or detect intent.
private struct NorthstarVisionComposer: View {
    let onSubmitPrompt: (String) -> Void
    let onSelectStar: () -> Void
    let onSelectMicrophone: () -> Void

    @State private var draftText = ""

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelectStar) {
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.7))
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("Open Northstar menu")

            TextField(
                "",
                text: $draftText,
                prompt: Text("Ask anything")
                    .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.4))
            )
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.85))
            .submitLabel(.send)
            .onSubmit(submit)

            Button(action: onSelectMicrophone) {
                Image(systemName: "mic")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.6))
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("Use microphone")

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NorthstarResponseTheme.warmWhite.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(NorthstarResponseTheme.warmWhite.opacity(0.14)))
            }
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial).opacity(0.55))
        .overlay(Capsule().strokeBorder(NorthstarResponseTheme.warmWhite.opacity(0.12), lineWidth: 1))
    }

    private func submit() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmitPrompt(trimmed)
        draftText = ""
    }
}

#Preview("Northstar Vision Screen") {
    NorthstarVisionScreen(
        onSubmitPrompt: { _ in },
        onSelectStar: {},
        onSelectMicrophone: {}
    )
}
