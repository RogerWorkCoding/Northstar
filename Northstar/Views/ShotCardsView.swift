import SwiftUI
import UIKit
import AVKit

// 🎬 Shot cards: Northstar plans a video like an art director. Each card holds one shot's
// prompt. "Make video" turns it into a real clip with Google Veo (a few per day);
// "Copy prompt" is still there for using it in another tool.

struct ShotCardsView: View {
    let shots: [NorthstarInsight.Shot]

    @State private var copied: Int?
    @State private var making: Int?
    @State private var videos: [Int: URL] = [:]
    @State private var problems: [Int: String] = [:]

    private let videoService = VideoService()

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

            if let url = videos[index] {
                VideoPlayer(player: AVPlayer(url: url))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Video for shot \(index + 1), \(shot.title)")
                ShareLink(item: url) {
                    Label("Share video", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
            } else if making == index {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Making your video… this can take a minute or two.")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }

            if let problem = problems[index] {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
            }

            HStack(spacing: 10) {
                if videos[index] == nil {
                    Button {
                        make(index: index, shot: shot)
                    } label: {
                        Label("Make video", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
                    }
                    .buttonStyle(.plain)
                    .disabled(making != nil)
                    .opacity(making != nil && making != index ? 0.5 : 1)
                    .accessibilityLabel("Make a video of shot \(index + 1), \(shot.title)")
                }

                Button {
                    UIPasteboard.general.string = shot.prompt
                    withAnimation(.easeOut(duration: 0.2)) { copied = index }
                } label: {
                    Label(copied == index ? "Copied" : "Copy prompt",
                          systemImage: copied == index ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.soft)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy prompt for shot \(index + 1), \(shot.title)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    /// One clip at a time; the button shows progress, then the video plays in the card.
    private func make(index: Int, shot: NorthstarInsight.Shot) {
        problems[index] = nil
        making = index
        Task {
            do {
                let url = try await videoService.make(prompt: shot.prompt, seconds: shot.seconds)
                withAnimation(.easeOut(duration: 0.25)) { videos[index] = url }
            } catch is CancellationError {
                // Left the screen: nothing to show.
            } catch {
                problems[index] = error.localizedDescription
            }
            making = nil
        }
    }
}
