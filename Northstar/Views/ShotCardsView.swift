import SwiftUI
import UIKit

// 🎬 Shot cards: Northstar plans a video like an art director. Each card holds one shot's
// prompt to copy into a video tool such as Google Flow (Veo). Northstar doesn't make the video.

struct ShotCardsView: View {
    let shots: [NorthstarInsight.Shot]

    @State private var copied: Int?

    private static let flowURL = URL(string: "https://labs.google/fx/tools/flow")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "film")
                Text("SHOTS").tracking(2)
                Text("·")
                Text("\(shots.reduce(0) { $0 + $1.seconds }) sec")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            ForEach(Array(shots.enumerated()), id: \.offset) { index, shot in
                card(index: index, shot: shot)
            }

            Link(destination: Self.flowURL) {
                HStack(spacing: 6) {
                    Text("Open Google Flow")
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.soft)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            }
            .accessibilityHint("Opens Google Flow in Safari")
        }
    }

    private func card(index: Int, shot: NorthstarInsight.Shot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("SHOT \(index + 1)").tracking(1.5)
                Text("·")
                Text("\(shot.seconds)s")
                if !shot.framing.isEmpty {
                    Text("·")
                    Text(shot.framing.lowercased())
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            Text(shot.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)

            Text(shot.prompt)
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Button {
                UIPasteboard.general.string = shot.prompt
                withAnimation(.easeOut(duration: 0.2)) { copied = index }
            } label: {
                Label(copied == index ? "Copied" : "Copy prompt",
                      systemImage: copied == index ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy prompt for shot \(index + 1), \(shot.title)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }
}
