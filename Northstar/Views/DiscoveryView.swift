import SwiftUI
import Supabase

// ✦ Discovery: the intelligent front door to Northstar. Opened by the ✦ star button in chat.
//
// Two layers of bubbles around the central star:
//   • Background: every real place in Northstar (from NorthstarDestinations, the same list as the ≡ menu),
//     as small muted icon bubbles, like the Apple Watch. Always there, always tappable, never in the way.
//   • Active: after the person types or speaks, 3–5 bubbles written from THEIR words come forward:
//     open a place, do a task in chat, ask one follow-up, or (when one really works) connect an app.
//     A place they ask for is PROMOTED from the background (no duplicate bubble).
// Three ways around: background bubbles (passive discovery), active bubbles (intelligent routing),
// and the ≡ menu (the complete list). Their words are used for this answer only; nothing is saved here.

// MARK: - Model

enum DiscoveryBubbleKind: Equatable {
    case destination, nativeCapability, connector, clarification
}

enum DiscoveryAction: Equatable {
    case navigate(NorthstarRoute)
    case beginChat(prompt: String, capability: String, opener: String)
    case connect(connector: String, prompt: String)
    case clarify(question: String)
    case more                                   // the full ≡ menu, when there isn't room for every place
}

struct DiscoveryBubble: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String?
    let kind: DiscoveryBubbleKind
    let action: DiscoveryAction
    let priority: Int
    let isPersistent: Bool
}

/// What Discovery hands back to chat.
enum DiscoveryResult: Equatable {
    case close
    case crisis(String)                          // crisis words: chat's crisis help answers
    case navigate(NorthstarRoute)
    case beginChat(prompt: String, capability: String, opener: String)
    case connect(connector: String, prompt: String)
}

nonisolated struct PathOption: Hashable, Sendable, Decodable {
    let label: String
    let icon: String
    let opener: String
    /// capability · navigate · clarify · connector
    var kind: String? = nil
    var destination: String? = nil
    var connector: String? = nil
}

@MainActor
enum PathService {
    private nonisolated struct Request: Encodable, Sendable {
        let text: String
        let destinations: [[String: String]]
        let offer: [String]
    }
    nonisolated struct Reply: Decodable, Sendable {
        var heard: String?
        var tone: String?
        var paths: [PathOption]?
        var crisis: Bool?
        var fallback: Bool?
    }

    /// nil when Northstar couldn't be reached or answered too slowly (about 6 seconds). Never made-up results.
    static func ways(for text: String) async -> Reply? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let call = Task { () -> Reply? in
            do {
                let r: Reply = try await SupabaseManager.shared.client.functions.invoke(
                    "northstar-paths",
                    options: FunctionInvokeOptions(body: Request(text: clean, destinations: NorthstarDestinations.forBrain, offer: [])))
                return r
            } catch { return nil }
        }
        let timer = Task {
            try? await Task.sleep(for: .seconds(6))
            call.cancel()
        }
        let reply = await call.value
        timer.cancel()
        guard let reply else { return nil }
        if reply.crisis == true { return reply }
        // The brain's own ready-made set is not an answer to THEIR words: treat it as "couldn't interpret".
        guard reply.fallback != true, (reply.paths?.count ?? 0) >= 3 else { return nil }
        return reply
    }
}

// MARK: - View

struct DiscoveryView: View {
    var onResult: (DiscoveryResult) -> Void
    var onMenu: () -> Void

    enum Phase: Equatable {
        case idle, listening, interpreting, showingSuggestions, navigating, startingChat, requestingConnection, error
    }

    @State private var state: Phase = .idle
    @State private var draft = ""                  // the composer; never cleared by a transition
    @State private var request = ""                // what Northstar is working on (their words)
    @State private var question: String?           // a follow-up they chose to answer
    @State private var reply: PathService.Reply?
    @State private var active: [DiscoveryBubble] = []
    @State private var shown = 0                   // active bubbles floated in so far
    @State private var picked: DiscoveryBubble?
    @State private var pickedSpot: CGPoint?
    @State private var dragging: (id: String, at: CGPoint)?
    @State private var pulse = false
    @State private var ripple = false
    @State private var speech = SpeechRecognizer()
    @FocusState private var typing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private let starSize: CGFloat = 190
    private let activeSize: CGFloat = 76
    private let backSize: CGFloat = 44

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.55)
    private let lavender = Color(red: 0.72, green: 0.70, blue: 1.0)
    private let glass = Color(red: 0.10, green: 0.14, blue: 0.38)
    private let mist = Color(red: 0.55, green: 0.63, blue: 0.80)      // muted gray-blue for background places

    @State private var promptTick = 0
    private var placeholder: String {
        if speech.isRecording { return "Listening\u{2026}" }
        if question != nil { return "Your answer\u{2026}" }
        return promptTick % 2 == 0 ? "What's on your mind?" : "Type or speak\u{2026}"
    }

    private var hasWords: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var bigText: Bool { typeSize.isAccessibilitySize }
    private var shownState: Phase { speech.isRecording ? .listening : state }
    private var suggesting: Bool { state == .showingSuggestions || picked != nil }

    // Every place in Northstar, most important first (the same list the ≡ menu uses).
    private var background: [DiscoveryBubble] {
        NorthstarDestinations.all.sorted { $0.priority < $1.priority }.map { d in
            DiscoveryBubble(id: "dest.\(d.route.rawValue)", title: d.title, symbol: d.symbol, kind: .destination,
                            action: .navigate(d.route), priority: d.priority, isPersistent: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geo in
                let size = geo.size
                let center = CGPoint(x: size.width / 2, y: size.height * 0.5)
                ZStack {

                    star
                        .scaleEffect(starScale * (pulse ? 1.18 : 1) * (speech.isRecording ? 1 + CGFloat(speech.level) * 0.08 : 1))
                        .brightness(speech.isRecording ? Double(speech.level) * 0.15 : 0)
                        .animation(.easeOut(duration: 0.12), value: speech.level)
                        .position(state == .startingChat ? CGPoint(x: center.x, y: -40) : center)
                        .opacity(state == .startingChat ? 0 : 1)
                        .accessibilityHidden(true)

                    Circle()
                        .stroke(gold.opacity(0.8), lineWidth: 2)
                        .frame(width: 70, height: 70)
                        .scaleEffect(ripple ? 3.2 : 0.6)
                        .opacity(ripple ? 0 : (picked != nil ? 0.9 : 0))
                        .position(center)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    wordsLayer(center: center, size: size)

                    orbits(center: center, size: size)
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .coordinateSpace(name: "discovery")
                .gesture(spinGesture(center: center))
                .onTapGesture { typing = false }
            }
            composer
                .opacity(state == .startingChat || state == .navigating ? 0 : 1)
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
        .task {
            // Trade the two prompts every few seconds, softly.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeInOut(duration: 0.6)) { promptTick += 1 }
            }
        }
    }

    // MARK: Top bar and composer

    private var topBar: some View {
        HStack {
            Button { onMenu() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Menu")
            .accessibilityHint("Shows every place in Northstar")
            Spacer()
            Text("Discovery")
                .font(.headline.weight(.regular))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { onResult(.close) } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back to chat")
        }
        .padding(.horizontal, 12)
        .opacity(state == .startingChat ? 0 : 1)
    }

    /// Always there: type or speak first, then edit and send again to refine.
    private var composer: some View {
        HStack(spacing: 10) {
            if speech.isRecording {
                VoiceBars(level: speech.level, color: gold, count: draft.isEmpty ? 14 : 6)
                    .transition(.opacity)
            }
            TextField("", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .overlay(alignment: .leading) {
                    // The question lives in the field: "What's on your mind?" gently trades places with "Type or speak…".
                    if draft.isEmpty {
                        Text(placeholder)
                            .id(placeholder)
                            .transition(.opacity)
                            .foregroundStyle(.white.opacity(0.6))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(question ?? "What's on your mind?")
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
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.22)))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .disabled(state == .interpreting || state == .startingChat || state == .navigating || state == .requestingConnection)
    }

    // MARK: Words on the sky

    @ViewBuilder
    private func wordsLayer(center: CGPoint, size: CGSize) -> some View {
        // All words sit in a band at the top, so the space around the star is free for the planets.
        let top = CGPoint(x: center.x, y: Orbits.topBand / 2)
        switch shownState {
        case .idle, .listening:
            if let question {
                Text(question)
                    .font(.system(size: 20, weight: .light))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .frame(width: size.width)
                    .position(top)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isHeader)
            }
        case .interpreting:
            Text("Thinking about your way forward\u{2026}")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .position(top)
                .transition(.opacity)
        case .error:
            HStack(spacing: 10) {
                Text("Couldn't reach Northstar.")
                    .font(.callout)
                Button { submit(again: true) } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
            .position(top)
        case .showingSuggestions, .navigating, .startingChat, .requestingConnection:
            // Their exact words, never a rewording.
            let heard = request.count > 60 ? String(request.prefix(57)) + "\u{2026}" : request
            VStack(spacing: 2) {
                Text("A few ways forward")
                    .font(.system(size: 20, weight: .light))
                Text("You said: \u{201C}\(heard)\u{201D}")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(width: size.width)
            .position(top)
            .opacity(picked == nil ? 1 : 0)
        }
    }

    // MARK: Bubbles

    /// Planets around the star: places on an outer orbit, suggestions on an inner one turning the other way.
    /// They drift on their own (about one turn every 2 minutes) and spin with a drag, then glide to a stop.
    @ViewBuilder
    private func orbits(center: CGPoint, size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: picked != nil)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            let turn = rotation(at: now)
            let o = Orbits.make(size: size, center: center, turn: turn, time: reduceMotion ? 0 : now, background: background,
                                active: Array(active.prefix(shown)), wordsAtTop: wordsAtTop,
                                starRadius: starRadius, activeSize: activeSize, backSize: backSize, bigText: bigText)
            ZStack {
                // Faint constellation lines from the star to each suggestion.
                Canvas { ctx, _ in
                    guard suggesting, !bigText else { return }
                    for b in active.prefix(shown) {
                        guard picked == nil || picked == b, let at = o.spots[b.id] else { continue }
                        var line = Path()
                        line.move(to: center)
                        line.addLine(to: at)
                        ctx.stroke(line, with: .color(gold.opacity(0.16)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(o.backs, id: \.id) { b in
                    let at = o.spots[b.id] ?? center
                    let seen = o.visibility[b.id] ?? 1
                    backgroundBubble(b)
                        .position(at)
                        .opacity((picked == nil ? (suggesting ? quietOpacity : restOpacity) : 0) * seen)
                        .allowsHitTesting(seen > 0.5 && picked == nil)
                        .onTapGesture { select(b, at: at, center: center) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(b.title)
                        .accessibilityValue("Place in Northstar")
                        .accessibilityHint(hint(for: b))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { select(b, at: at, center: center) }
                }
                if let more = o.more {
                    moreBubble
                        .position(more)
                        .opacity((picked == nil ? (suggesting ? quietOpacity : restOpacity) : 0) * (o.visibility["more"] ?? 1))
                        .onTapGesture { onMenu() }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("More places")
                        .accessibilityHint("Opens the full menu")
                        .accessibilityAddTraits(.isButton)
                }
                ForEach(Array(active.prefix(shown).enumerated()), id: \.element.id) { i, b in
                    let at = spot(of: b, home: o.spots[b.id] ?? center)
                    activeBubble(b, index: i)
                        .scaleEffect(scale(of: b))
                        .opacity(opacity(of: b))
                        .position(at)
                        .gesture(drag(b, at: at, center: center))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(b.title)
                        .accessibilityValue(kindName(b.kind))
                        .accessibilityHint(hint(for: b))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { select(b, at: at, center: center) }
                }
            }
        }
    }

    // MARK: Spinning

    @State private var spin: Double = 0               // where a drag left the orbits (radians)
    @State private var flick: Double = 0              // how fast they were moving when let go (radians/second)
    @State private var flickAt: TimeInterval = 0
    @State private var lastAngle: Double?
    @State private var lastTime: TimeInterval = 0
    @State private var startedAt = Date.timeIntervalSinceReferenceDate

    /// Total turn right now: a slow drift of their own, plus spins, plus a flick that glides to a stop.
    private func rotation(at now: TimeInterval) -> Double {
        let drift = reduceMotion ? 0 : (now - startedAt) * (2 * .pi / 120)
        let glide = 0.6 * flick * (1 - exp(-(now - flickAt) / 0.6))
        return drift + spin + glide
    }

    /// Drag anywhere on the sky to spin the planets around the star, like turning a dial.
    private func spinGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("discovery"))
            .onChanged { v in
                guard picked == nil, dragging == nil else { return }
                let now = Date.timeIntervalSinceReferenceDate
                let angle = atan2(v.location.y - center.y, v.location.x - center.x)
                if lastAngle == nil {
                    // Fold any glide still running into the spin, so the planets don't jump.
                    spin += 0.6 * flick * (1 - exp(-(now - flickAt) / 0.6))
                    flick = 0
                }
                if let last = lastAngle {
                    var d = angle - last
                    if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                    spin += d
                    let dt = max(now - lastTime, 0.001)
                    flick = 0.7 * flick + 0.3 * (d / dt)
                }
                lastAngle = angle
                lastTime = now
            }
            .onEnded { _ in
                lastAngle = nil
                flickAt = Date.timeIntervalSinceReferenceDate
                flick = max(-6, min(6, flick))
            }
    }

    /// Is there text in the top band right now? (Planets fade as they pass behind it.)
    private var wordsAtTop: Bool {
        switch shownState {
        case .idle, .listening: return question != nil
        default: return true
        }
    }

    private var restOpacity: Double { contrast == .increased ? 1 : 0.9 }
    private var quietOpacity: Double { contrast == .increased ? 0.85 : 0.55 }

    /// A place in Northstar: small, muted gray-blue, icon only (VoiceOver reads its name).
    private func backgroundBubble(_ b: DiscoveryBubble) -> some View {
        ZStack {
            Circle().fill(mist.opacity(contrast == .increased ? 0.45 : 0.24))
            Circle().strokeBorder(.white.opacity(contrast == .increased ? 0.6 : 0.28), lineWidth: 1)
            Image(systemName: b.symbol ?? "circle")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(width: backSize, height: backSize)
        .contentShape(Circle())
    }

    private var moreBubble: some View {
        ZStack {
            Circle().fill(mist.opacity(0.18))
            Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1)
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: backSize, height: backSize)
        .contentShape(Circle())
    }

    /// Northstar's response: frosted glass, lit from above, gold-to-lavender rim. A promoted place keeps its icon.
    private func activeBubble(_ b: DiscoveryBubble, index: Int) -> some View {
        let isPicked = picked == b
        let tint = [lavender, gold, Color(red: 0.62, green: 0.80, blue: 1.0), lavender, gold][index % 5]
        let quietKind = b.kind == .clarification
        return ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 0.20, green: 0.22, blue: 0.48), glass, Color(red: 0.05, green: 0.07, blue: 0.20)],
                                         startPoint: .top, endPoint: .bottom))
                .opacity(0.9)
            Circle().fill(RadialGradient(colors: [tint.opacity(0.30), .clear], center: UnitPoint(x: 0.3, y: 0.25),
                                         startRadius: 1, endRadius: activeSize * 0.75))
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: activeSize * 0.62, height: activeSize * 0.30)
                .offset(y: -activeSize * 0.26)
                .blur(radius: 1.5)
            Circle().strokeBorder(
                LinearGradient(colors: [gold.opacity(isPicked ? 1 : 0.85), tint.opacity(0.35), lavender.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: isPicked ? 2.5 : 1.2, dash: quietKind ? [4, 3] : []))
            VStack(spacing: 2) {
                if let symbol = b.kind == .destination ? b.symbol : nil {
                    Image(systemName: symbol).font(.system(size: 14))
                }
                Text(b.title)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            .padding(8)
            .foregroundStyle(.white.opacity(0.96))
            if isPicked {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(gold)
                    .offset(y: activeSize * 0.36)
            }
        }
        .frame(width: activeSize, height: activeSize)
        .shadow(color: (isPicked ? gold : tint).opacity(isPicked ? 0.7 : 0.25), radius: isPicked ? 18 : 9)
    }

    // MARK: The star

    private var star: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [gold.opacity(suggesting ? 0.30 : 0.18), gold.opacity(0.06), .clear],
                                     center: .center, startRadius: 4, endRadius: starSize * 0.9))
                .frame(width: starSize * 1.8, height: starSize * 1.8)
            NorthstarVisionStarMark(size: starSize)
        }
        .shadow(color: gold.opacity(suggesting ? 0.5 : 0.28), radius: 34)
    }

    /// Alone it waits a little smaller; with suggestions it steps back so the bubbles have room.
    private var starScale: CGFloat {
        switch state {
        case .showingSuggestions, .navigating, .requestingConnection: return 0.62
        case .startingChat: return 0.4
        default: return 0.78
        }
    }
    private var starRadius: CGFloat { starSize * starScale * 0.42 }

    // MARK: Bubble state

    private func spot(of b: DiscoveryBubble, home: CGPoint) -> CGPoint {
        if picked == b, let pickedSpot { return pickedSpot }
        if let dragging, dragging.id == b.id { return dragging.at }
        return home
    }

    private func scale(of b: DiscoveryBubble) -> CGFloat {
        guard picked == b else { return 1 }
        return state == .startingChat ? 0.3 : 1.08
    }

    private func opacity(of b: DiscoveryBubble) -> Double {
        guard let picked else { return 1 }
        if picked != b { return 0 }
        return state == .startingChat && pickedSpot != nil ? 0 : 1
    }

    private func kindName(_ k: DiscoveryBubbleKind) -> String {
        switch k {
        case .destination: return "Place in Northstar"
        case .nativeCapability: return "Action"
        case .connector: return "Connection"
        case .clarification: return "Follow-up question"
        }
    }

    private func hint(for b: DiscoveryBubble) -> String {
        switch b.action {
        case .navigate(let r): return NorthstarDestinations.info(r).hint
        case .beginChat: return "Starts a chat about this"
        case .connect: return "Opens the connection, then continues your request"
        case .clarify: return "Asks you one more thing, then suggests new ways forward"
        case .more: return "Opens the full menu"
        }
    }

    // MARK: Gestures

    /// Tap an active bubble, or drag it into the star.
    private func drag(_ b: DiscoveryBubble, at: CGPoint, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("discovery"))
            .onChanged { v in
                guard state == .showingSuggestions, picked == nil else { return }
                if hypot(v.translation.width, v.translation.height) > 6 { dragging = (b.id, v.location) }
            }
            .onEnded { v in
                guard state == .showingSuggestions, picked == nil else { return }
                let moved = hypot(v.translation.width, v.translation.height)
                let end = dragging?.at ?? at
                if moved <= 6 || hypot(end.x - center.x, end.y - center.y) < 70 {
                    select(b, at: end, center: center)
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { dragging = nil }
                }
            }
    }

    // MARK: Steps

    /// They said something (first time, an edit, or an answer to a follow-up): interpret it and bring bubbles.
    private func submit(again: Bool = false) {
        let said = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty, state != .interpreting, picked == nil else { return }
        if speech.isRecording { speech.stopRecording() }
        typing = false
        // An answer to a follow-up keeps the original request with it.
        if let question, !again {
            request = "\(request). \(question) \(said)"
            self.question = nil
            draft = request
        } else if !again {
            request = said
        }
        withAnimation(.easeOut(duration: 0.25)) { shown = 0 }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.6)) { state = .interpreting }
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { pulse = true }
            withAnimation(.easeInOut(duration: 0.35).delay(0.2)) { pulse = false }
        }
        AccessibilityNotification.Announcement("Thinking about your way forward").post()
        let words = request
        Task {
            async let answer = PathService.ways(for: words)
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.0))
            guard let r = await answer else {
                // Keep their words and every place; offer a retry. Never made-up results.
                withAnimation(.easeInOut(duration: 0.3)) { state = .error; active = [] }
                AccessibilityNotification.Announcement("Couldn't reach Northstar. Try again.").post()
                return
            }
            if r.crisis == true { finish(.crisis(words)); return }
            reply = r
            active = Self.bubbles(from: r.paths ?? [], request: words)
            withAnimation(.easeInOut(duration: 0.3)) { state = .showingSuggestions }
            AccessibilityNotification.Announcement("\(active.count) ways forward found").post()
            for i in 0..<active.count {
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(120)) }
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.8)) {
                    shown = i + 1
                }
            }
        }
    }

    /// Paths from the brain → typed bubbles. A place keeps the background bubble's id, so it's promoted, not copied.
    static func bubbles(from paths: [PathOption], request: String) -> [DiscoveryBubble] {
        var seen = Set<String>()
        var out: [DiscoveryBubble] = []
        for (i, p) in paths.enumerated() {
            let b: DiscoveryBubble
            switch p.kind {
            case "navigate":
                guard let id = p.destination, let route = NorthstarRoute(rawValue: id) else { continue }
                let d = NorthstarDestinations.info(route)
                b = DiscoveryBubble(id: "dest.\(id)", title: d.title, symbol: d.symbol, kind: .destination,
                                    action: .navigate(route), priority: i, isPersistent: true)
            case "clarify":
                b = DiscoveryBubble(id: "ask.\(p.label)", title: p.label, symbol: "questionmark.circle", kind: .clarification,
                                    action: .clarify(question: p.opener.isEmpty ? p.label : p.opener), priority: i, isPersistent: false)
            case "connector":
                guard let c = p.connector else { continue }
                b = DiscoveryBubble(id: "conn.\(c)", title: p.label, symbol: p.icon, kind: .connector,
                                    action: .connect(connector: c, prompt: request), priority: i, isPersistent: false)
            default:
                let opener = p.opener.isEmpty ? "Let's \(p.label.lowercased()) together. Where would you like to start?" : p.opener
                b = DiscoveryBubble(id: "do.\(p.label)", title: p.label, symbol: p.icon, kind: .nativeCapability,
                                    action: .beginChat(prompt: request, capability: p.label, opener: opener), priority: i, isPersistent: false)
            }
            if seen.insert(b.id).inserted { out.append(b) }
        }
        return Array(out.prefix(5))
    }

    private func select(_ b: DiscoveryBubble, at: CGPoint, center: CGPoint) {
        guard picked == nil, state != .interpreting else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        switch b.action {
        case .clarify(let q):
            // Stay in Discovery: ask, then bring new bubbles after they answer.
            withAnimation(.easeInOut(duration: 0.3)) {
                question = q
                draft = ""
                shown = 0
                active = []
                state = .idle
            }
            typing = true
            AccessibilityNotification.Announcement(q).post()
        case .more:
            onMenu()
        case .navigate(let route):
            // Highlight, ease a little toward the star, then open the place directly (no chat first).
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                picked = b
                dragging = nil
                pickedSpot = CGPoint(x: at.x + (center.x - at.x) * 0.25, y: at.y + (center.y - at.y) * 0.25)
                state = .navigating
            }
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 450))
                onResult(.navigate(route))
            }
        case .connect(let connector, let prompt):
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                picked = b
                dragging = nil
                pickedSpot = CGPoint(x: at.x + (center.x - at.x) * 0.5, y: at.y + (center.y - at.y) * 0.5)
                state = .requestingConnection
            }
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 500))
                onResult(.connect(connector: connector, prompt: prompt))
            }
        case .beginChat(let prompt, let capability, let opener):
            // Merge into the star, then chat opens with their request and Northstar's first line.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                picked = b
                dragging = nil
                pickedSpot = at
            }
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 300))
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeIn(duration: 0.8)) { pickedSpot = center }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 800))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.15)) { pulse = true }
                    withAnimation(.easeOut(duration: 0.9)) { ripple = true }
                    try? await Task.sleep(for: .milliseconds(160))
                    withAnimation(.easeInOut(duration: 0.25)) { pulse = false }
                    try? await Task.sleep(for: .milliseconds(250))
                }
                finish(.beginChat(prompt: prompt, capability: capability, opener: opener))
            }
        }
    }

    /// The star rises and everything fades, so chat appears on the same sky.
    private func finish(_ result: DiscoveryResult) {
        if speech.isRecording { speech.stopRecording() }
        Task {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.7)) { state = .startingChat }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 700))
            onResult(result)
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

// MARK: - Orbits

/// Where every planet is at a given turn, worked out the same way every time (no random placement).
/// Places go evenly around an outer orbit; suggestions around an inner one (turning the other way), so the
/// two never meet. A planet passing behind the words fades out and can't be tapped until it's clear.
struct Orbits {
    var spots: [String: CGPoint] = [:]
    var visibility: [String: Double] = [:]
    var backs: [DiscoveryBubble] = []
    var more: CGPoint?

    /// Room kept at the top for "A few ways forward / You said".
    static let topBand: CGFloat = 64

    static func make(size: CGSize, center: CGPoint, turn: Double, time: Double, background: [DiscoveryBubble],
                     active: [DiscoveryBubble], wordsAtTop: Bool, starRadius: CGFloat,
                     activeSize: CGFloat, backSize: CGFloat, bigText: Bool) -> Orbits {
        var out = Orbits()
        let rb = backSize / 2, ra = activeSize / 2
        let gap: CGFloat = 10
        let words: CGRect? = wordsAtTop ? CGRect(x: 0, y: 0, width: size.width, height: topBand) : nil

        func visible(_ p: CGPoint, _ r: CGFloat) -> Double {
            // 1 when clear of the words at the top, fading to 0 within 18 points of them.
            guard let words else { return 1 }
            let below = (p.y - r) - words.maxY
            return below >= 18 ? 1 : max(0, Double(below / 18))
        }

        // Rings hug the star as true circles.
        let maxX = size.width / 2 - 6, maxY = size.height / 2 - 6
        func ring(_ r: CGFloat, _ half: CGFloat) -> (rx: CGFloat, ry: CGFloat) {
            let c = min(r, maxX - half, maxY - half)
            return (c, c)
        }
        func perimeter(_ rx: CGFloat, _ ry: CGFloat) -> Double { 2 * .pi * (Double(rx * rx + ry * ry) / 2).squareRoot() }

        // Each ring turns at its own pace (inner a little faster, alternate rings the other way),
        // with a soft wobble, so the cluster feels free rather than like a grid.
        func place(_ k: Int, of n: Int, ringIndex i: Int, rx: CGFloat, ry: CGFloat, seed: Int) -> CGPoint {
            let pace = (i % 2 == 0 ? 1.0 : -0.75) / (1 + 0.35 * Double(i))
            let a = -Double.pi / 2 + Double(k) * 2 * .pi / Double(max(n, 1)) + Double(i) * 0.4 + turn * pace
            let wobble = 3 * sin(time * 0.6 + Double(seed) * 1.7)
            return CGPoint(x: center.x + (rx + wobble) * cos(a), y: center.y + (ry + wobble) * sin(a))
        }

        var r = starRadius + gap

        // Suggestions first, closest to the star.
        if !active.isEmpty {
            if bigText {
                for (i, b) in active.enumerated() {
                    out.spots[b.id] = CGPoint(x: center.x, y: topBand + ra + CGFloat(i) * (activeSize + gap))
                }
                r = size.height  // big text: places step aside (the ≡ menu still has them all)
            } else {
                let (rx, ry) = ring(r + ra, ra)
                for (k, b) in active.enumerated() {
                    out.spots[b.id] = place(k, of: active.count, ringIndex: 0, rx: rx, ry: ry, seed: k)
                }
                r += activeSize + gap
            }
        }

        // Places in rings around that, most important closest; whatever doesn't fit goes behind "More".
        let activeIds = Set(active.map(\.id))
        var queue = background.filter { !activeIds.contains($0.id) }[...]
        var ringIndex = active.isEmpty || bigText ? 0 : 1
        var shown: [DiscoveryBubble] = []
        while !queue.isEmpty {
            let (rx, ry) = ring(r + rb, rb)
            guard r + rb <= maxY, r + rb <= maxX + 2 else { break }       // out of room on screen
            let fit = max(3, Int(perimeter(rx, ry) / Double(backSize + gap)))
            // No room for another ring after this one (sideways or up and down).
            let next = r + backSize + gap + rb
            let last = next > maxX - rb || next > maxY - rb
            var take = min(fit, queue.count)
            let needsMore = last && queue.count > fit
            if needsMore { take = fit - 1 }
            let ringItems = Array(queue.prefix(take))
            queue = queue.dropFirst(take)
            let n = ringItems.count + (needsMore ? 1 : 0)
            for (k, b) in ringItems.enumerated() {
                let p = place(k, of: n, ringIndex: ringIndex, rx: rx, ry: ry, seed: b.priority + 7)
                out.spots[b.id] = p
                out.visibility[b.id] = visible(p, rb)
                shown.append(b)
            }
            if needsMore {
                let p = place(n - 1, of: n, ringIndex: ringIndex, rx: rx, ry: ry, seed: 99)
                out.more = p
                out.visibility["more"] = visible(p, rb)
                queue = []
            }
            r += backSize + gap
            ringIndex += 1
            if last { break }
        }
        if !queue.isEmpty, out.more == nil, let lastShown = shown.popLast(), let p = out.spots[lastShown.id] {
            out.spots[lastShown.id] = nil
            out.more = p
            out.visibility["more"] = out.visibility[lastShown.id] ?? 1
        }
        out.backs = shown
        return out
    }
}
