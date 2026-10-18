import SwiftUI
import Supabase

// ✦ Path Forward: the last onboarding screen (and later, an empty chat).
// The person always goes first: only the star and one question, no options until they've said something.
// Then 3–5 ways forward, written from THEIR words, float around a big star. Tap one, or drag it into the star,
// and chat opens on that path. Most are things Northstar can do now; at most one may be a connector
// (looks the same), and only one that really works in the app. Never a menu, never connector-only.
// Drag the sky to move all the bubbles (like Apple Watch); they settle back around the star.
// Always skippable. Their words are used for this answer only; nothing is saved.

/// What the person chose, handed to chat.
enum PathChoice: Equatable {
    case skip
    case words(String)                       // "Something else", a direct request, or crisis words
    case path(label: String, words: String)
}

nonisolated struct PathOption: Identifiable, Hashable, Sendable, Decodable {
    var id: String { label }
    let label: String
    let icon: String
    let opener: String
    /// "capability" (Northstar helps now) or "connector" (connect an app for a better answer).
    var kind: String? = nil
    var connector: String? = nil
}

@MainActor
enum PathService {
    private nonisolated struct Request: Encodable, Sendable { let text: String }
    nonisolated struct Reply: Decodable, Sendable {
        var heard: String?
        var tone: String?
        var paths: [PathOption]?
        var crisis: Bool?
        var fallback: Bool?
    }

    static let fallback: [PathOption] = [
        .init(label: "Organize priorities", icon: "list.number", opener: ""),
        .init(label: "Plan my week", icon: "calendar", opener: ""),
        .init(label: "Learn something new", icon: "book", opener: ""),
        .init(label: "Talk it through", icon: "bubble.left.and.bubble.right", opener: ""),
    ]

    /// Never throws and never waits more than about 4 seconds: the ready-made paths cover anything slow.
    static func ways(for text: String) async -> Reply {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return Reply(heard: nil, tone: "vague", paths: fallback, fallback: true) }
        let call = Task { () -> Reply? in
            do {
                let r: Reply = try await SupabaseManager.shared.client.functions.invoke(
                    "northstar-paths", options: FunctionInvokeOptions(body: Request(text: clean)))
                return r
            } catch { return nil }
        }
        let timer = Task {
            try? await Task.sleep(for: .seconds(4))
            call.cancel()
        }
        let first = await call.value
        timer.cancel()
        if let first, first.crisis == true || (first.paths?.count ?? 0) >= 3 { return first }
        return Reply(heard: nil, tone: "practical", paths: fallback, fallback: true)
    }
}

struct PathForwardView: View {
    var onDone: (PathChoice) -> Void

    private enum Phase { case asking, thinking, choosing, merging, leaving }

    @State private var phase: Phase = .asking
    @State private var text = ""
    @State private var reply: PathService.Reply?
    @State private var paths: [PathOption] = []
    @State private var shown = 0                    // bubbles floated in so far
    @State private var picked: PathOption?
    @State private var pan: CGSize = .zero
    @State private var dragging: (id: String, at: CGPoint)?
    @State private var mergeTo: CGPoint?
    @State private var pulse = false
    @State private var ripple = false
    @State private var speech = SpeechRecognizer()
    @FocusState private var typing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private let starSize: CGFloat = 150                // the star's full size, in the middle
    private let bubble: CGFloat = 82
    private let somethingElse = "Something else"

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.55)
    private let lavender = Color(red: 0.72, green: 0.70, blue: 1.0)
    private let glass = Color(red: 0.10, green: 0.14, blue: 0.38)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
            let starTop = CGPoint(x: size.width / 2, y: 44 + 24 + 32)

            ZStack {
                // Faint constellation lines from the star to each bubble.
                if phase == .choosing || phase == .merging, !listLayout {
                    TimelineView(.animation(paused: reduceMotion)) { tl in
                        Canvas { ctx, _ in
                            for (i, p) in allBubbles.enumerated() where i < shown {
                                guard picked == nil || picked == p else { continue }
                                let at = spot(i, of: allBubbles.count, center: center, size: size, time: tl.date)
                                var line = Path()
                                line.move(to: center)
                                line.addLine(to: at)
                                ctx.stroke(line, with: .color(gold.opacity(0.18)), lineWidth: 1)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                // The star: small at the top while asking, big in the middle while choosing.
                star
                    .scaleEffect(starScale * (pulse ? 1.22 : 1))
                    .position(starPosition(center: center, top: starTop))
                    .opacity(phase == .leaving ? 0 : 1)
                    .accessibilityHidden(true)

                Circle()
                    .stroke(gold.opacity(0.8), lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(ripple ? 3.2 : 0.6)
                    .opacity(ripple ? 0 : (phase == .merging ? 0.9 : 0))
                    .position(center)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                switch phase {
                case .asking:
                    askingLayer
                case .thinking:
                    Text("Finding a few ways forward\u{2026}")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))
                        .position(x: center.x, y: center.y + starSize * 0.75)
                        .transition(.opacity)
                case .choosing, .merging, .leaving:
                    choosingLayer(center: center, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .coordinateSpace(name: "pathSky")
            .gesture(skyPan)
        }
        .foregroundStyle(.white)
        .overlay(alignment: .topTrailing) {
            if phase == .asking || phase == .choosing {
                Button("Skip for now") { finish(.skip) }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, 20)
            }
        }
        .onChange(of: speech.transcript) {
            if speech.isRecording { text = speech.transcript }
        }
        .onDisappear { if speech.isRecording { speech.stopRecording() } }
    }

    // MARK: Asking

    private var askingLayer: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 44 + 24 + 64 + 28)
            Text("What's on your mind?")
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("A few words is enough. I'll suggest some ways forward.")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField("", text: $text, prompt: Text(speech.isRecording ? "Listening\u{2026}" : "Too much to do this week\u{2026}")
                    .foregroundStyle(.white.opacity(0.5)), axis: .vertical)
                    .lineLimit(1...3)
                    .focused($typing)
                    .submitLabel(.go)
                    .onSubmit { if hasWords { start() } }
                Button { toggleMic() } label: {
                    Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(speech.isRecording ? "Stop listening" : "Speak instead")
            }
            .padding(.leading, 16)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.18)))

            Spacer(minLength: 12)

            // Appears once they've said something: the person always goes first.
            Button { start() } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
            .opacity(hasWords ? 1 : 0)
            .disabled(!hasWords)
            .accessibilityHidden(!hasWords)
            .animation(.easeInOut(duration: 0.3), value: hasWords)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private var hasWords: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Choosing

    private var allBubbles: [PathOption] {
        paths + [PathOption(label: somethingElse, icon: "ellipsis", opener: "")]
    }

    private var listLayout: Bool { typeSize.isAccessibilitySize }

    @ViewBuilder
    private func choosingLayer(center: CGPoint, size: CGSize) -> some View {
        let heard = (reply?.heard ?? "").isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : (reply?.heard ?? "")
        VStack(spacing: 6) {
            Spacer().frame(height: 44 + 12)
            Text(reply?.fallback == true ? "Here are a few places to start." : "Here are a few ways forward.")
                .font(.system(size: 24, weight: .light))
                .accessibilityAddTraits(.isHeader)
            if !heard.isEmpty {
                Text("You said: \u{201C}\(heard)\u{201D}")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            Spacer()
            Text("Pick one. You can change direction any time.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 36)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .frame(width: size.width, height: size.height)
        .opacity(phase == .choosing ? 1 : 0)

        if listLayout {
            // Big text: a simple list of buttons instead of the floating ring.
            VStack(spacing: 12) {
                ForEach(allBubbles) { p in
                    Button { choose(p, from: center, center: center) } label: {
                        Label(p.label, systemImage: p.icon)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Capsule().fill(glass.opacity(0.8)))
                            .overlay(Capsule().strokeBorder(gold.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .position(x: center.x, y: center.y + 40)
        } else {
            TimelineView(.animation(paused: reduceMotion || phase != .choosing)) { tl in
                ZStack {
                    ForEach(Array(allBubbles.enumerated()), id: \.element.id) { i, p in
                        let home = spot(i, of: allBubbles.count, center: center, size: size, time: tl.date)
                        let at = position(of: p, home: home, center: center)
                        let d = hypot(at.x - center.x, at.y - center.y)
                        // Apple Watch feel: bigger near the star, smaller toward the edges.
                        let fisheye = reduceMotion ? 1 : max(0.7, min(1.08, 1.3 - d / (size.width * 0.9)))
                        bubbleView(p, quiet: p.label == somethingElse)
                            .scaleEffect(scale(for: p, fisheye: fisheye))
                            .opacity(opacity(for: p, index: i))
                            .position(at)
                            .gesture(bubbleDrag(p, at: at, center: center))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(p.label)
                            .accessibilityValue("Way forward \(i + 1) of \(allBubbles.count)")
                            .accessibilityHint("Starts a chat about this")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { choose(p, from: at, center: center) }
                    }
                }
            }
        }
    }

    private func bubbleView(_ p: PathOption, quiet: Bool) -> some View {
        let isPicked = picked == p
        return ZStack {
            Circle().fill(glass.opacity(quiet ? 0.45 : 0.62))
            Circle().fill(RadialGradient(colors: [lavender.opacity(0.28), .clear], center: .topLeading,
                                         startRadius: 2, endRadius: bubble * 0.8))
            Circle().strokeBorder(
                LinearGradient(colors: [gold.opacity(isPicked ? 1 : 0.75), lavender.opacity(0.5)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: isPicked ? 2.5 : 1.2)
            Text(p.label)
                .font(.system(size: quiet ? 12 : 13, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(10)
                .foregroundStyle(.white.opacity(quiet ? 0.75 : 1))
            if isPicked {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(gold)
                    .offset(y: bubble * 0.34)
            }
        }
        .frame(width: bubble, height: bubble)
        .shadow(color: gold.opacity(isPicked ? 0.6 : 0.12), radius: isPicked ? 16 : 8)
    }

    // MARK: Geometry

    private var star: some View {
        NorthstarVisionStarMark(size: starSize)
            .shadow(color: gold.opacity(phase == .asking ? 0.2 : 0.45), radius: 30)
    }

    private var starScale: CGFloat {
        switch phase {
        case .asking: return 64 / starSize
        case .leaving: return 0.5
        default: return 1
        }
    }

    private func starPosition(center: CGPoint, top: CGPoint) -> CGPoint {
        switch phase {
        case .asking, .leaving: return top
        default: return center
        }
    }

    /// Where bubble i rests: evenly around the star, starting at the top, drifting gently.
    private func spot(_ i: Int, of n: Int, center: CGPoint, size: CGSize, time: Date) -> CGPoint {
        let r = min(size.width * 0.36, size.height * 0.26)
        let a = -Double.pi / 2 + Double(i) * 2 * .pi / Double(max(n, 1))
        let t = reduceMotion ? 0 : time.timeIntervalSinceReferenceDate
        let drift = reduceMotion ? 0.0 : 4.0
        return CGPoint(x: center.x + r * cos(a) + pan.width + drift * sin(t * 0.9 + Double(i) * 1.3),
                       y: center.y + r * sin(a) + pan.height + drift * cos(t * 0.7 + Double(i) * 1.3))
    }

    private func position(of p: PathOption, home: CGPoint, center: CGPoint) -> CGPoint {
        if picked == p, let mergeTo { return mergeTo }
        if let dragging, dragging.id == p.id { return dragging.at }
        return home
    }

    private func scale(for p: PathOption, fisheye: CGFloat) -> CGFloat {
        if picked == p { return phase == .merging && mergeTo != nil ? 0.3 : 1.08 }
        return fisheye
    }

    private func opacity(for p: PathOption, index: Int) -> Double {
        guard index < shown else { return 0 }
        if let picked { return picked == p ? (phase == .merging ? 0 : 1) : 0.3 }
        return 1
    }

    // MARK: Gestures

    /// Drag the sky: every bubble moves together, then settles back around the star.
    private var skyPan: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard phase == .choosing, !reduceMotion, dragging == nil else { return }
                pan = CGSize(width: v.translation.width * 0.6, height: v.translation.height * 0.6)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { pan = .zero }
            }
    }

    /// Tap a bubble, or drag it into the star.
    private func bubbleDrag(_ p: PathOption, at: CGPoint, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("pathSky"))
            .onChanged { v in
                guard phase == .choosing else { return }
                if hypot(v.translation.width, v.translation.height) > 6 {
                    dragging = (p.id, v.location)
                }
            }
            .onEnded { v in
                guard phase == .choosing else { return }
                let moved = hypot(v.translation.width, v.translation.height)
                let end = dragging?.at ?? at
                if moved <= 6 || hypot(end.x - center.x, end.y - center.y) < 70 {
                    choose(p, from: end, center: center)
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { dragging = nil }
                }
            }
    }

    // MARK: Steps

    private func start() {
        if speech.isRecording { speech.stopRecording() }
        typing = false
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.9)) { phase = .thinking }
        let words = text
        Task {
            async let answer = PathService.ways(for: words)
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.3))
            let r = await answer
            // Crisis words: no bubbles, straight to chat, where Northstar's crisis help answers.
            if r.crisis == true { finish(.words(words)); return }
            reply = r
            paths = Array((r.paths ?? PathService.fallback).prefix(5))
            withAnimation(.easeInOut(duration: 0.3)) { phase = .choosing }
            AccessibilityNotification.Announcement("\(allBubbles.count) ways forward found").post()
            for i in 0..<allBubbles.count {
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(120)) }
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.75)) {
                    shown = i + 1
                }
            }
        }
        if !reduceMotion {
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeInOut(duration: 0.2)) { pulse = true }
                withAnimation(.easeInOut(duration: 0.2).delay(0.2)) { pulse = false }
            }
        }
    }

    private func choose(_ p: PathOption, from: CGPoint, center: CGPoint) {
        guard phase == .choosing, picked == nil else { return }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let choice: PathChoice = p.label == somethingElse
            ? (words.isEmpty ? .skip : .words(words))
            : .path(label: p.label, words: words)
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            picked = p
            dragging = nil
            mergeTo = from
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 300))
            phase = .merging
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeIn(duration: 0.9)) { mergeTo = center }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 900))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.15)) { pulse = true }
                withAnimation(.easeOut(duration: 0.9)) { ripple = true }
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.easeInOut(duration: 0.25)) { pulse = false }
                try? await Task.sleep(for: .milliseconds(250))
            }
            finish(choice)
        }
    }

    /// The star rises and everything fades, so the chat appears on the same sky.
    private func finish(_ choice: PathChoice) {
        if speech.isRecording { speech.stopRecording() }
        Task {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.8)) { phase = .leaving }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 800))
            onDone(choice)
        }
    }

    private func toggleMic() {
        if speech.isRecording { speech.stopRecording(); return }
        Task {
            guard await speech.requestPermissions() else { return }
            try? speech.startRecording()
        }
    }
}
