import SwiftUI
import AVKit

// 🕘 Video history (Videos → top): every video made in Northstar, newest first,
// whether it was saved or not. A paid video is never lost if the app closes before Save.
// Tap a video to watch it. Not saved yet → Save puts it in Videos or any folder.

struct VideoHistoryView: View {
    @State private var made: [MadeVideo] = []
    @State private var saved: [SavedVideo] = []
    @State private var folders: [VideoFolder] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var saving: MadeVideo?
    @State private var playing: PlayItem?

    private let library = VideoLibraryService()
    private struct PlayItem: Identifiable { let id = UUID(); let url: URL; let title: String }

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            if !loaded {
                ProgressView().tint(NorthstarChatStyle.text)
            } else if failed {
                message(icon: "exclamationmark.triangle", title: "Couldn't load your video history",
                        detail: "Check your connection and try again.")
            } else if made.isEmpty {
                message(icon: "clock.arrow.circlepath", title: "No videos made yet",
                        detail: "Videos you make from shot cards show up here, even before you save them.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(made) { video in row(video) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Video history")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $saving) { video in
            MovePicker(folders: folders, excluding: [], title: "Save to…") { target in
                Task {
                    try? await library.save(.made(storagePath: video.storagePath, title: video.title), in: target)
                    saving = nil
                    await load()
                    NotificationCenter.default.post(name: .northstarVideosChanged, object: nil)
                }
            }
        }
        .sheet(item: $playing) { item in
            NavigationStack {
                VideoPlayer(player: AVPlayer(url: item.url))
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { playing = nil } } }
            }
        }
    }

    private func row(_ video: MadeVideo) -> some View {
        let savedCopy = saved.first { $0.storagePath == video.storagePath }
        return HStack(spacing: 12) {
            Button { Task { await play(video) } } label: {
                HStack(spacing: 12) {
                    ZStack {
                        NorthstarChatStyle.cardStrong
                        Image(systemName: "play.fill").foregroundStyle(NorthstarChatStyle.text)
                    }
                    .frame(width: 64, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(savedCopy?.title ?? video.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .lineLimit(2)
                        Text("\(video.when) · \(video.seconds) sec")
                            .font(.caption)
                            .foregroundStyle(NorthstarChatStyle.label)
                        if let savedCopy {
                            Label("Saved in \(place(of: savedCopy))", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.savedGreen)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(savedCopy?.title ?? video.title), made \(video.when)")

            if savedCopy == nil {
                Button { saving = video } label: {
                    Text("Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save \(video.title) to Videos")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NorthstarChatStyle.card)
        )
    }

    /// "Videos" or the folder path, e.g. "Wood carving › Spoons".
    private func place(of video: SavedVideo) -> String {
        guard let id = video.folderId, let f = folders.first(where: { $0.id == id }) else { return "Videos" }
        return VideoLibraryService.path(of: f, in: folders)
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(NorthstarChatStyle.label)
            Text(title).font(.headline).foregroundStyle(NorthstarChatStyle.text)
            Text(detail).font(.subheadline).foregroundStyle(NorthstarChatStyle.soft).multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func load() async {
        do {
            async let m = library.madeVideos()
            async let s = library.videos()
            async let f = library.folders()
            (made, saved, folders) = try await (m, s, f)
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }

    private func play(_ video: MadeVideo) async {
        if let url = try? await library.playURL(storagePath: video.storagePath) {
            playing = PlayItem(url: url, title: video.title)
        }
    }
}

#Preview {
    NavigationStack { VideoHistoryView() }
}
