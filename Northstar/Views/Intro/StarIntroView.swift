import SwiftUI
import AVFoundation

// ✦ The opening: Northstar's star rising over the mountains (the same clip as the website), shown when
// the app starts. It plays to just past the star's brightest moment (about 6.5 seconds), then fades
// into the app. Tap anywhere to skip. Silent. With Reduce Motion on, it's skipped.

struct StarIntroView: View {
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var finished = false

    private static let length: Double = 6.5
    static var clip: URL? { Bundle.main.url(forResource: "NorthstarStar", withExtension: "mp4") }

    var body: some View {
        ZStack {
            // The clip's own night sky, so there's never a flash of white or black around it.
            Color(red: 0.06, green: 0.09, blue: 0.14).ignoresSafeArea()
            if let player {
                VideoLayer(player: player)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement()
        .accessibilityLabel("Northstar")
        .accessibilityHint("Double-tap to skip")
        .accessibilityAddTraits(.isButton)
        .task { await play() }
    }

    private func play() async {
        guard !reduceMotion, let url = Self.clip else { finish(); return }
        let p = AVPlayer(url: url)
        p.isMuted = true
        p.preventsDisplaySleepDuringVideoPlayback = false
        // Don't stop the person's music or podcast.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        player = p
        p.play()
        try? await Task.sleep(for: .seconds(Self.length))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        player?.pause()
        onDone()
    }
}

/// Plays the clip filling the screen (like the website), without any controls.
private struct VideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
