import SwiftUI
import WebKit

// ▶️ Lesson videos: real YouTube tutorials the brain found (used by modules like Wood carving).
// Tap one to watch it inside Northstar with YouTube's own player.

struct LessonVideosCard: View {
    let videos: [NorthstarInsight.LessonVideo]
    @State private var playing: NorthstarInsight.LessonVideo?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle")
                Text("VIDEOS").tracking(2)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            ForEach(videos, id: \.id) { video in
                Button { playing = video } label: { row(video) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Video: \(video.title)")
                    .accessibilityHint("Plays the video")
            }
        }
        .sheet(item: $playing) { video in
            VideoSheet(video: video)
        }
    }

    private func row(_ video: NorthstarInsight.LessonVideo) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.id)/mqdefault.jpg")) { image in
                image.resizable().aspectRatio(16 / 9, contentMode: .fill)
            } placeholder: {
                NorthstarChatStyle.card
            }
            .frame(width: 112, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(Image(systemName: "play.fill").foregroundStyle(.white).shadow(radius: 3))  // on the thumbnail

            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NorthstarChatStyle.card))
        .contentShape(Rectangle())
    }
}

struct VideoSheet: View {
    let video: NorthstarInsight.LessonVideo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                YouTubePlayer(id: video.id)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(video.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let url = URL(string: video.url) {
                    Link(destination: url) {
                        Label("Open in YouTube", systemImage: "arrow.up.right")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// YouTube's own embedded player (privacy-enhanced mode), inline on the phone.
struct YouTubePlayer: UIViewRepresentable {
    let id: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .black
        guard let url = URL(string: "https://www.youtube-nocookie.com/embed/\(id)?playsinline=1&rel=0") else { return view }
        var request = URLRequest(url: url)
        // YouTube's player needs to know which app is showing it.
        request.setValue("https://mynorthstarlabs.app", forHTTPHeaderField: "Referer")
        view.load(request)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
