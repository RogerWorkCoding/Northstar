import SwiftUI
import Supabase

// ✦ Discovery: step inside Northstar's thinking. Chat is for conversation; Discovery is for finding the best path.
// Opened from the ✦ star button in chat. The ≡ in its corner opens the main menu.
// The person always goes first: only the star and the text field until they type or speak.
// Then the star reacts and 3–5 bubbles, written from THEIR words, float around it. Most are things Northstar can
// do now; at most one may be a connector (looks the same, only ones that really work). They can pick a bubble,
// or keep typing to refine and get new bubbles. Picking one merges it into the star and opens chat on that path.
// Their words are used for this answer only; nothing is saved here.

/// What the person chose, handed to chat.
enum PathChoice: Equatable {
    case skip
    case words(String)                                     // crisis words: chat's crisis help answers
    case path(label: String, words: String, opener: String)
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
        .init(label: "Organize priorities", icon: "list.number", opener: "Let's sort what matters from what can wait. What's on your plate right now?"),
        .init(label: "Plan my week", icon: "calendar", opener: "Let's plan your week together. What's the one thing that matters most to finish?"),
        .init(label: "Learn something new", icon: "book", opener: "Let's find a good way in. What would you love to learn?"),
        .init(label: "Talk it through", icon: "bubble.left.and.bubble.right", opener: "I'm here. What's on your mind most today?"),
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

struct DiscoveryView: View {
    var onChoose: (PathChoice) -> Void
    var onMenu: () -> Void

    private enum Phase { case idle, thinking, choosing, merging, leaving }

    @State private var phase: Phase = .idle
    @State private var draft = ""                   // what's in the field now
    @State private var asked: [String] = []         // everything they've said here, in order
    @State private var reply: PathService.Reply?
    @State private var paths: [PathOption] = []
    @State private var shown = 0                    // bubbles floated in so far
    @State private var round = 0                    // a new set of bubbles each time they refine
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

    private let starSize: CGFloat = 190
    private let bubble: CGFloat = 78

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.55)
    private let lavender = Color(red: 0.72, green: 0.70, blue: 1.0)
    private let glass = Color(red: 0.10, green: 0.14, blue: 0.38)

    private var hasWords: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var listLayout: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geo in
                let size = geo.size
                let center = CGPoint(x: size.width / 2, y: size.height * 0.5)
                ZStack {
                    constellation(center: center, size: size)

                    star
                        .scaleEffect(starScale * (pulse ? 1.18 : 1) * (speech.isRecording ? 1 + CGFloat(speech.level) * 0.08 : 1))
                        .brightness(speech.isRecording ? Double(speech.level) * 0.15 : 0)
                        .animation(.easeOut(duration: 0.12), value: speech.level)
                        .position(phase == .leaving ? CGPoint(x: center.x, y: -40) : center)
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

                    wordsLayer(center: center, size: size)

                    if phase == .choosing || phase == .merging {
                        bubbles(center: center, size: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .coordinateSpace(name: "discovery")
                .gesture(skyPan)
                .onTapGesture { typing = false }
            }
            inputBar
                .opacity(phase == .merging || phase == .leaving ? 0 : 1)
        }
        .foregroundStyle(.white)
        .background {
            ZStack {
                NorthstarVisionLandscapeBackground()
                LinearGradient(colors: [Color.black.opacity(0.25), Color.black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: speech.transcript) {
            if speech.isRecording { draft = speech.transcript }
        }
        .onDisappear { if speech.isRecording { speech.stopRecording() } }
    }

    // MARK: Top and bottom

    private var topBar: some View {
        HStack {
            Button { onMenu() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Menu")
            Spacer()
            Text("Discovery")
                .font(.headline.weight(.regular))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { onChoose(.skip) } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back to chat")
        }
        .padding(.horizontal, 12)
        .opacity(phase == .leaving ? 0 : 1)
    }

    /// Always there: type or speak first, then again to refine.
    private var inputBar: some View {
        HStack(spacing: 10) {
            if speech.isRecording {
                VoiceBars(level: speech.level, color: gold, count: draft.isEmpty ? 14 : 6)
                    .transition(.opacity)
            }
            TextField("", text: $draft,
                      prompt: Text(speech.isRecording ? "Listening\u{2026}"
                                   : asked.isEmpty ? "Type or speak\u{2026}" : "Add more, or pick a bubble\u{2026}")
                        .foregroundStyle(.white.opacity(0.5)),
                      axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .submitLabel(.send)
                .onSubmit { if hasWords { submit() } }
            Button { toggleMic() } label: {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic")
                    .font(.title3)
                    .foregroundStyle(speech.isRecording ? gold : .white)
                    .frame(width: 40, height: 44)
                    .background { ListeningRing(active: speech.isRecording, color: gold).frame(width: 34, height: 34) }
            }
            .accessibilityLabel(speech.isRecording ? "Stop listening" : "Speak")
            if hasWords {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(gold)
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel("Send")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasWords)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.18)))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .disabled(phase == .thinking || phase == .merging || phase == .leaving)
    }

    // MARK: Words on the sky

    @ViewBuilder
    private func wordsLayer(center: CGPoint, size: CGSize) -> some View {
        switch phase {
        case .idle:
            Text("What's on your mind?")
                .font(.system(size: 26, weight: .light))
                .position(x: center.x, y: center.y + starSize * 0.62)
                .transition(.opacity)
                .accessibilityAddTraits(.isHeader)
        case .thinking:
            Text("Thinking about your way forward\u{2026}")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.75))
                .position(x: center.x, y: center.y + starSize * 0.62)
                .transition(.opacity)
        case .choosing:
            // Their exact words, never a rewording.
            let last = asked.last ?? ""
            let heard = last.count > 60 ? String(last.prefix(57)) + "\u{2026}" : last
            VStack(spacing: 4) {
                Text(reply?.fallback == true ? "A few places to start" : "A few ways forward")
                    .font(.system(size: 22, weight: .light))
                Text("You said: \u{201C}\(heard)\u{201D}")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(width: size.width)
            .position(x: center.x, y: 34)
            .transition(.opacity)
        case .merging, .leaving:
            EmptyView()
        }
    }

    // MARK: Bubbles

    private func constellation(center: CGPoint, size: CGSize) -> some View {
        TimelineView(.animation(paused: reduceMotion || phase != .choosing)) { tl in
            Canvas { ctx, _ in
                guard (phase == .choosing || phase == .merging), !listLayout else { return }
                for (i, p) in paths.enumerated() where i < shown {
                    guard picked == nil || picked == p else { continue }
                    let at = spot(i, of: paths.count, center: center, size: size, time: tl.date)
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

    @ViewBuilder
    private func bubbles(center: CGPoint, size: CGSize) -> some View {
        if listLayout {
            // Big text: a simple list of buttons instead of the floating ring.
            VStack(spacing: 12) {
                ForEach(paths) { p in
                    Button { choose(p, from: center, center: center) } label: {
                        Label(p.label, systemImage: p.icon)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Capsule().fill(glass.opacity(0.85)))
                            .overlay(Capsule().strokeBorder(gold.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .position(x: center.x, y: center.y + 20)
        } else {
            TimelineView(.animation(paused: reduceMotion || phase != .choosing)) { tl in
                ZStack {
                    ForEach(Array(paths.enumerated()), id: \.element.id) { i, p in
                        let home = spot(i, of: paths.count, center: center, size: size, time: tl.date)
                        let at = position(of: p, home: home)
                        let d = hypot(at.x - center.x, at.y - center.y)
                        // Apple Watch feel: bigger near the star, smaller toward the edges.
                        let fisheye = reduceMotion ? 1 : max(0.7, min(1.08, 1.3 - d / (size.width * 0.9)))
                        bubbleView(p, index: i)
                            .scaleEffect(scale(for: p, fisheye: fisheye))
                            .opacity(opacity(for: p, index: i))
                            .position(at)
                            .gesture(bubbleDrag(p, at: at, center: center))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(p.label)
                            .accessibilityValue("Way forward \(i + 1) of \(paths.count)")
                            .accessibilityHint("Starts a chat about this")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { choose(p, from: at, center: center) }
                    }
                }
                .id(round)
            }
        }
    }

    /// Frosted glass: a deep navy body lit from above, a soft sheen, a gold-to-lavender rim and a faint glow.
    private func bubbleView(_ p: PathOption, index: Int) -> some View {
        let isPicked = picked == p
        // Each bubble leans a little warmer or cooler, so they feel like different lights, not buttons.
        let tint = [lavender, gold, Color(red: 0.62, green: 0.80, blue: 1.0), lavender, gold][index % 5]
        return ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 0.20, green: 0.22, blue: 0.48), glass, Color(red: 0.05, green: 0.07, blue: 0.20)],
                                         startPoint: .top, endPoint: .bottom))
                .opacity(0.88)
            Circle().fill(RadialGradient(colors: [tint.opacity(0.30), .clear], center: UnitPoint(x: 0.3, y: 0.25),
                                         startRadius: 1, endRadius: bubble * 0.75))
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: bubble * 0.62, height: bubble * 0.30)
                .offset(y: -bubble * 0.26)
                .blur(radius: 1.5)
            Circle().strokeBorder(
                LinearGradient(colors: [gold.opacity(isPicked ? 1 : 0.85), tint.opacity(0.35), lavender.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: isPicked ? 2.5 : 1.2)
            Text(p.label)
                .font(.system(size: 12.5, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(9)
                .foregroundStyle(.white.opacity(0.96))
            if isPicked {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(gold)
                    .offset(y: bubble * 0.36)
            }
        }
        .frame(width: bubble, height: bubble)
        .shadow(color: (isPicked ? gold : tint).opacity(isPicked ? 0.7 : 0.28), radius: isPicked ? 18 : 10)
    }

    // MARK: The star

    private var star: some View {
        ZStack {
            // A warm halo, so the star reads as the brightest light in the sky.
            Circle()
                .fill(RadialGradient(colors: [gold.opacity(phase == .idle ? 0.16 : 0.32), gold.opacity(0.06), .clear],
                                     center: .center, startRadius: 4, endRadius: starSize * 0.9))
                .frame(width: starSize * 1.8, height: starSize * 1.8)
            NorthstarVisionStarMark(size: starSize)
        }
        .shadow(color: gold.opacity(phase == .idle ? 0.25 : 0.5), radius: 34)
    }

    /// Alone, the star waits a little smaller; once it understands, it grows into the center of the bubbles.
    private var starScale: CGFloat {
        switch phase {
        case .idle: return 0.78
        case .leaving: return 0.4
        default: return 1
        }
    }

    // MARK: Geometry

    /// Where bubble i rests: evenly around the star, starting at the top, drifting gently.
    private func spot(_ i: Int, of n: Int, center: CGPoint, size: CGSize, time: Date) -> CGPoint {
        let r = min(size.width * 0.37, size.height * 0.30)
        let a = -Double.pi / 2 + Double(i) * 2 * .pi / Double(max(n, 1))
        let t = reduceMotion ? 0 : time.timeIntervalSinceReferenceDate
        let drift = reduceMotion ? 0.0 : 4.0
        return CGPoint(x: center.x + r * cos(a) + pan.width + drift * sin(t * 0.9 + Double(i) * 1.3),
                       y: center.y + r * sin(a) + pan.height + drift * cos(t * 0.7 + Double(i) * 1.3))
    }

    private func position(of p: PathOption, home: CGPoint) -> CGPoint {
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
        if let picked { return picked == p ? (phase == .merging ? 0 : 1) : 0 }
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
        DragGesture(minimumDistance: 0, coordinateSpace: .named("discovery"))
            .onChanged { v in
                guard phase == .choosing else { return }
                if hypot(v.translation.width, v.translation.height) > 6 { dragging = (p.id, v.location) }
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

    /// They said something (first time or to refine): the star reacts, then new bubbles come.
    private func submit() {
        let said = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty, phase == .idle || phase == .choosing else { return }
        if speech.isRecording { speech.stopRecording() }
        typing = false
        asked.append(said)
        draft = ""
        let context = asked.joined(separator: ". ")
        withAnimation(.easeOut(duration: 0.25)) { shown = 0 }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.6)) { phase = .thinking }
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { pulse = true }
            withAnimation(.easeInOut(duration: 0.35).delay(0.2)) { pulse = false }
        }
        AccessibilityNotification.Announcement("Thinking about your way forward").post()
        Task {
            async let answer = PathService.ways(for: context)
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.0))
            let r = await answer
            // Crisis words: no bubbles, straight to chat, where Northstar's crisis help answers.
            if r.crisis == true { finish(.words(context)); return }
            reply = r
            paths = Array((r.paths ?? PathService.fallback).prefix(5))
            round += 1
            pan = .zero
            withAnimation(.easeInOut(duration: 0.3)) { phase = .choosing }
            AccessibilityNotification.Announcement("\(paths.count) ways forward found").post()
            for i in 0..<paths.count {
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(120)) }
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.75)) {
                    shown = i + 1
                }
            }
        }
    }

    private func choose(_ p: PathOption, from: CGPoint, center: CGPoint) {
        guard phase == .choosing, picked == nil else { return }
        let words = asked.joined(separator: ". ")
        let opener = p.opener.isEmpty ? "Let's \(p.label.lowercased()) together. Where would you like to start?" : p.opener
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
            finish(.path(label: p.label, words: words, opener: opener))
        }
    }

    /// The star rises and everything fades, so chat appears on the same sky.
    private func finish(_ choice: PathChoice) {
        if speech.isRecording { speech.stopRecording() }
        Task {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.8)) { phase = .leaving }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 800))
            onChoose(choice)
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
