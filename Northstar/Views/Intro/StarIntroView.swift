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
/// The clip is tall (720 x 1280) with the star about a third of the way down. On a tall phone screen it fits
/// naturally; in a wide window (Mac, iPad sideways) a plain "fill" crops the middle and pushes the star up
/// near the top edge. So the video is placed by hand: it always fills the window, and slides so the star
/// sits a bit above the middle, where it does on the phone.
private struct VideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.player = player
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        let playerLayer = AVPlayerLayer()
        /// The clip's shape, and where its star is (fraction of the clip's height from the top).
        private let clipSize = CGSize(width: 720, height: 1280)
        private let starInClip: CGFloat = 0.33
        /// Where the star should land (fraction of the window's height from the top).
        private let starOnScreen: CGFloat = 0.42

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width, h = bounds.height
            guard w > 0, h > 0 else { return }
            // Big enough to cover the whole window (like "fill").
            let scale = max(w / clipSize.width, h / clipSize.height)
            let vw = clipSize.width * scale, vh = clipSize.height * scale
            // Slide up or down so the star lands at starOnScreen, without ever showing an edge.
            var y = h * starOnScreen - vh * starInClip
            y = min(0, max(h - vh, y))
            let x = (w - vw) / 2
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = CGRect(x: x, y: y, width: vw, height: vh)
            CATransaction.commit()
        }
    }
}
