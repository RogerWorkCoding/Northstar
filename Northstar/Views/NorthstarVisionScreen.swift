import SwiftUI

// Arrival screen: the landscape + star + wordmark are the hero, with a lightweight
// functional composer at the bottom whose only job is to capture first intent and
// hand it to NorthstarRootView — all real chat behavior (send pipeline, star menu,
// microphone) lives in ContentView, untouched.
struct NorthstarVisionScreen: View {
    let onSubmitPrompt: (String) -> Void
    let onSelectStar: () -> Void
    let onSelectMicrophone: () -> Void

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
/// instead of competing with it. Purely decorative (the functional star control
/// lives in the composer below, mirroring ContentView's sparkle menu button).
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
