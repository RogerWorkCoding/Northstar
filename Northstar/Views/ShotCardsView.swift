import SwiftUI
import UIKit
import AVKit

// 🎬 Shot cards: Northstar plans a video like an art director. Each card holds one shot's
// prompt. "Make video" turns it into a real clip with Google Veo (a few per day);
// "Copy prompt" is still there for using it in another tool.
// "Make full video" makes all the shots at once and joins them into one 15–25 second video
// (Veo stops at 8 seconds a clip, so longer videos are shots joined like a real edit).

struct ShotCardsView: View {
    let shots: [NorthstarInsight.Shot]
    var suggestedFolder: String?

    @State private var copied: Int?
    @State private var store = VideoStore.shared

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

            if shots.count >= 2 { fullVideo }

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
                .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
            }
            .accessibilityHint("Opens Google Flow in Safari")
        }
    }

    // MARK: Full video: all the shots joined

    private var fullVideo: some View {
        let key = VideoStore.filmKey(shots)
        let total = shots.reduce(0) { $0 + $1.seconds }
        let ready = shots.filter { store.files[$0.prompt] != nil }.count
        return VStack(alignment: .leading, spacing: 10) {
            if let url = store.films[key], let player = store.filmPlayer(for: key) {
                Text("YOUR VIDEO · \(total) SEC")
                    .font(.caption.weight(.semibold)).tracking(1.5)
                    .foregroundStyle(NorthstarChatStyle.label)
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Full video, \(total) seconds, \(shots.count) shots")
                ShareLink(item: url) {
                    Label("Share or save to Photos", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
            } else if store.makingFilm == key {
                HStack(spacing: 10) {
                    ProgressView().tint(NorthstarChatStyle.text)
                    Text(ready < shots.count
                         ? "Making \(shots.count) shots… \(ready) of \(shots.count) ready. This takes 2–3 minutes."
                         : "Joining the shots…")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                Button {
                    store.makeFilm(shots)
                } label: {
                    Label("Make full video · \(total) sec", systemImage: "film.stack")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                }
                .buttonStyle(.plain)
                .disabled(store.busy)
                .opacity(store.busy ? 0.5 : 1)
                .accessibilityHint("Makes all \(shots.count) shots and joins them into one video")
                Text("Uses \(shots.count - ready) of your daily videos.")
                    .font(.caption)
                    .foregroundStyle(NorthstarChatStyle.label)
            }
            if let problem = store.filmProblems[key] {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
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

            if let url = store.files[shot.prompt], let player = store.player(for: shot.prompt) {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Video for shot \(index + 1), \(shot.title)")
                if let path = store.storagePaths[shot.prompt] {
                    SaveVideoCard(items: [.made(storagePath: path, title: shot.title)], suggestedFolder: suggestedFolder)
                }
                ShareLink(item: url) {
                    Label("Share or save to Photos", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
            } else if store.making.contains(shot.prompt) {
                HStack(spacing: 10) {
                    ProgressView().tint(NorthstarChatStyle.text)
                    Text("Making your video… this can take a minute or two.")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }

            if let problem = store.problems[shot.prompt] {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
            }

            HStack(spacing: 10) {
                if store.files[shot.prompt] == nil {
                    Button {
                        store.make(prompt: shot.prompt, seconds: shot.seconds)
                    } label: {
                        Label("Make video", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.onPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.busy)
                    .opacity(store.busy && !store.making.contains(shot.prompt) ? 0.5 : 1)
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
                        .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy prompt for shot \(index + 1), \(shot.title)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }
}
