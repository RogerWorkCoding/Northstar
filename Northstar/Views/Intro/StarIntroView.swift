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
        v.backdropLayer.player = player
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        let playerLayer = AVPlayerLayer()
        /// Wide windows only (the Mac, iPad sideways): the same clip, filling and blurred, behind the real one,
        /// so the star isn't blown up and the sides aren't empty (Roger, Oct 19: "the star is too close").
        let backdropLayer = AVPlayerLayer()
        private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        /// The clip's shape, and where its star is (fraction of the clip's height from the top).
        private let clipSize = CGSize(width: 720, height: 1280)
        private let starInClip: CGFloat = 0.33
        /// Where the star should land (fraction of the window's height from the top).
        private let starOnScreen: CGFloat = 0.42

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            playerLayer.videoGravity = .resizeAspect
            backdropLayer.videoGravity = .resizeAspectFill
            backdropLayer.isHidden = true
            blur.isHidden = true
            layer.addSublayer(backdropLayer)
            addSubview(blur)
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width, h = bounds.height
            guard w > 0, h > 0 else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let wide = w > h
            backdropLayer.isHidden = !wide
            blur.isHidden = !wide
            if wide {
                // The whole clip at full height, centered; the blurred copy fills the sides.
                let scale = h / clipSize.height
                let vw = clipSize.width * scale
                backdropLayer.frame = bounds
                blur.frame = bounds
                bringSubviewToFront(blur)
                playerLayer.removeFromSuperlayer()
                layer.addSublayer(playerLayer)
                playerLayer.frame = CGRect(x: (w - vw) / 2, y: 0, width: vw, height: h)
            } else {
                // Tall screens (the phone): cover the whole screen, and slide so the star sits a bit above the middle.
                let scale = max(w / clipSize.width, h / clipSize.height)
                let vw = clipSize.width * scale, vh = clipSize.height * scale
                var y = h * starOnScreen - vh * starInClip
                y = min(0, max(h - vh, y))
                playerLayer.frame = CGRect(x: (w - vw) / 2, y: y, width: vw, height: vh)
            }
            CATransaction.commit()
        }
    }
}
