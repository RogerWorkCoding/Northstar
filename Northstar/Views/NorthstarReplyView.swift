import SwiftUI

// Q2 chat design (approved): Northstar's reply has no bubble — large, clear
// text on the night sky. When Northstar is guiding, a small stage chip sits
// above the reply, "What I heard" pills below it, then one-tap save cards.
// Quick questions show only the answer.

/// Northstar's colors. Each one has a Night value (navy, the original look) and a Day value
/// (warm cream paper with navy ink, easier for long reading and in sunlight). The app follows
/// Settings → Appearance: Automatic (the phone's light/dark setting), Day or Night.
/// The home screen with the star and mountains always stays Night.
enum NorthstarChatStyle {
    // Ink
    static let text = dyn(0xF2F4FF, 0x16213F)
    static let soft = dyn(0xC9D3FF, 0x3D4870)
    static let label = dyn(0xAEB9E6, 0x5C6688)
    static let linkBlue = dyn(0x9EBFFF, 0x2C4FB0)        // links in replies
    static let savedGreen = dyn(0xCFF5E3, 0x1E7A4C)
    static let warning = dyn(0xFFCCB3, 0xA0401E)         // "Couldn't save" lines
    // Surfaces
    static let background = dyn(0x141F40, 0xF6F1E6)      // screens like Search, Videos, Projects
    static let userBubble = dyn(0x2B3C7A, 0x1E2B57)
    static let onUserBubble = dyn(0xF2F4FF, 0xFFFFFF)
    static let card = dyn(0xFFFFFF, 0xFFFFFF, darkAlpha: 0.06)        // cards on the page
    static let cardStrong = dyn(0xFFFFFF, 0xFFFFFF, darkAlpha: 0.10)  // raised cards, chips
    static let stroke = dyn(0xFFFFFF, 0xE2D9C6, darkAlpha: 0.22)      // card and capsule edges
    // Main button (e.g. Save): light pill on Night, navy pill on Day.
    static let primaryFill = dyn(0xE8ECFF, 0x1E2B57)
    static let onPrimary = dyn(0x0D1736, 0xFFFFFF)
    // Send button in the chat field (white arrow on both).
    static let sendFill = dyn(0xFFFFFF, 0x1E2B57, darkAlpha: 0.20)
    // The small star in the chat header on Day (gold); Night uses the glowing star.
    static let starGold = dyn(0xF2F4FF, 0xB9852A)

    /// A color with a Night value and a Day value.
    nonisolated private static func dyn(_ dark: UInt32, _ light: UInt32, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light ? rgb(light, 1) : rgb(dark, darkAlpha)
        })
    }

    nonisolated private static func rgb(_ hex: UInt32, _ alpha: CGFloat) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Your message: one soft blue bubble on the right.
struct UserMessageView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.system(size: 17))
                .lineSpacing(3)
                .foregroundStyle(NorthstarChatStyle.onUserBubble)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20, bottomLeadingRadius: 20,
                        bottomTrailingRadius: 6, topTrailingRadius: 20,
                        style: .continuous
                    )
                    .fill(NorthstarChatStyle.userBubble)
                )
        }
        .padding(.horizontal, 20)
    }
}

/// Northstar's reply: no bubble, plus stage, pills and save cards when guiding.
struct NorthstarReplyView: View {
    let text: String
    let insight: NorthstarInsight?
    /// Saves one suggestion; returns true when it worked.
    var onSave: (NorthstarInsight.Save) async -> UUID? = { _ in nil }
    /// Removes a just-saved item; returns true when it worked.
    var onUndo: (UUID) async -> Bool = { _ in false }
    /// Tells the chat a pill was wrong, so Northstar is corrected next time.
    var onRemovePill: (String) -> Void = { _ in }
    /// The person picked one of the three directions.
    var onChooseDirection: (NorthstarInsight.Direction) -> Void = { _ in }
    /// The direction already chosen (from the chat), if any.
    var chosenDirection: String? = nil
    /// Only the newest reply can be chosen from, and not while Northstar is thinking.
    var canChooseDirection: Bool = true
    /// "Use this" on a From before card: bring that line into the conversation.
    var onUseFromBefore: (Note) -> Void = { _ in }
    /// Card already used or set aside (kept by the chat, so it survives scrolling).
    var fromBeforeDone: Bool = false
    var onDismissFromBefore: () -> Void = {}
    /// Subjects: what happened to this reply's subject card ("kept", "dismissed", "undone"), kept by the chat.
    var subjectState: String? = nil
    var onKeepSubject: (NorthstarInsight.SubjectOffer) -> Void = { _ in }
    var onDismissSubject: () -> Void = {}
    var onUndoSubject: (NorthstarInsight.SubjectUpdate) -> Void = { _ in }

    @State private var whyOpen = false
    @State private var removedPills: Set<NorthstarInsight.Heard> = []
    @State private var cardStates: [NorthstarInsight.Save: CardState] = [:]
    @State private var savedIds: [NorthstarInsight.Save: UUID] = [:]

    private enum CardState { case saving, saved, dismissed, failed }

    private var guiding: NorthstarInsight? {
        guard let insight, insight.isGuiding else { return nil }
        return insight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if insight?.crisis == true {
                CrisisHelpCard()
            }

            if let insight = guiding, let stage = insight.stage {
                stageChip(stage: stage, reason: insight.stageReason)
            }

            // Bold product names can be links (checked on the server); tap opens Safari.
            Text(Self.formatted(text))
                .font(.system(size: 18))
                .foregroundStyle(NorthstarChatStyle.text)
                .tint(NorthstarChatStyle.linkBlue)
                .northstarReadingStyle()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let offer = insight?.subjectOffer {
                SubjectOfferCard(offer: offer, state: subjectState, onKeep: onKeepSubject, onDismiss: onDismissSubject)
            }

            if let update = insight?.subjectUpdate {
                SubjectUpdatedLine(update: update, state: subjectState, onUndo: onUndoSubject)
            }

            if let earlier = insight?.fromBefore.first, !fromBeforeDone {
                FromBeforeCard(note: earlier, canUse: canChooseDirection, onUse: onUseFromBefore, onDismiss: onDismissFromBefore)
            }

            if let places = insight?.places, !places.isEmpty {
                PlacesMapCard(places: places)
            }

            if let shots = insight?.shots, !shots.isEmpty {
                ShotCardsView(shots: shots, suggestedFolder: insight?.folderHint)
            }

            if let videos = insight?.videos, !videos.isEmpty {
                LessonVideosCard(videos: videos)
                SaveVideoCard(items: videos.map { .youtube(id: $0.id, title: $0.title) },
                              suggestedFolder: insight?.folderHint)
            }

            if let sources = insight?.sources, !sources.isEmpty {
                SourcesRow(sources: sources)
            }

            if let visual = insight?.visual {
                WireframeCard(visual: visual)
            }

            if let directions = insight?.directions, directions.count == 3 {
                DirectionsView(
                    directions: directions,
                    chosenName: chosenDirection,
                    canChoose: canChooseDirection,
                    onChoose: onChooseDirection
                )
            }

            if let insight = guiding {
                let pills = insight.heard.filter { !removedPills.contains($0) }
                if !pills.isEmpty {
                    heardSection(pills)
                }
                ForEach(insight.proposedSaves, id: \.self) { save in
                    saveCard(save)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Stage chip

    private func stageChip(stage: String, reason: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                whyOpen.toggle()
            } label: {
                HStack(spacing: 8) {
                    NorthStarGlyph().fill(NorthstarChatStyle.soft).frame(width: 12, height: 12)
                    Text(stage.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(whyOpen ? 180 : 0))
                }
                .foregroundStyle(NorthstarChatStyle.soft)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(NorthstarChatStyle.soft.opacity(0.10)))
                .overlay(Capsule().strokeBorder(NorthstarChatStyle.soft.opacity(0.35), lineWidth: 1))
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stage: \(stage)")
            .accessibilityHint("Shows why")

            if whyOpen, let reason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .foregroundStyle(NorthstarChatStyle.soft)
            }
        }
    }

    // MARK: What I heard

    private func heardSection(_ pills: [NorthstarInsight.Heard]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("WHAT I HEARD")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                Spacer()
                Text("Tap ✕ to correct me")
                    .font(.system(size: 13))
            }
            .foregroundStyle(NorthstarChatStyle.label)

            PillFlowLayout(spacing: 8) {
                ForEach(pills, id: \.self) { pill in
                    HStack(spacing: 0) {
                        // Plain words only (approved): no group labels on pills.
                        Text(pill.text)
                            .foregroundStyle(NorthstarChatStyle.text)
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                _ = removedPills.insert(pill)
                            }
                            onRemovePill(pill.text)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NorthstarChatStyle.soft)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(pill.text)")
                    }
                    .font(.system(size: 15))
                    .padding(.leading, 14)
                    .padding(.trailing, 2)
                    .frame(height: 40)
                    .background(Capsule().fill(NorthstarChatStyle.card))
                    .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                }
            }
        }
    }

    // MARK: Save card

    @ViewBuilder
    private func saveCard(_ save: NorthstarInsight.Save) -> some View {
        switch cardStates[save] {
        case .dismissed:
            EmptyView()
        case .saved:
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                Text(save.savedLine)
                    .font(.system(size: 15))
                Spacer()
                Button {
                    guard let id = savedIds[save] else { return }
                    Task {
                        let ok = await onUndo(id)
                        withAnimation(.easeOut(duration: 0.2)) {
                            if ok {
                                savedIds[save] = nil
                                cardStates[save] = nil
                            }
                        }
                    }
                } label: {
                    Text("Undo")
                        .font(.system(size: 15, weight: .semibold))
                        .underline()
                        .foregroundStyle(NorthstarChatStyle.text)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo save")
            }
            .foregroundStyle(NorthstarChatStyle.savedGreen)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Capsule().fill(NorthstarChatStyle.savedGreen.opacity(0.12)))
            .overlay(Capsule().strokeBorder(NorthstarChatStyle.savedGreen.opacity(0.45), lineWidth: 1))
            .accessibilityElement(children: .contain)
        default:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "star")
                        .font(.system(size: 12, weight: .semibold))
                    Text(save.question.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                }
                .foregroundStyle(NorthstarChatStyle.label)

                Text(save.text)
                    .font(.system(size: 17))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)

                if !save.reason.isEmpty {
                    Text(save.reason)
                        .font(.system(size: 14))
                        .foregroundStyle(NorthstarChatStyle.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if cardStates[save] == .failed {
                    Text("Couldn't save. Try again.")
                        .font(.system(size: 14))
                        .foregroundStyle(NorthstarChatStyle.warning)
                }

                HStack(spacing: 10) {
                    Button {
                        cardStates[save] = .saving
                        Task {
                            let id = await onSave(save)
                            withAnimation(.easeOut(duration: 0.2)) {
                                savedIds[save] = id
                                cardStates[save] = id != nil ? .saved : .failed
                            }
                        }
                    } label: {
                        Text(cardStates[save] == .saving ? "Saving…" : "Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NorthstarChatStyle.onPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                    }
                    .buttonStyle(.plain)
                    .disabled(cardStates[save] == .saving)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            cardStates[save] = .dismissed
                        }
                    } label: {
                        Text("Not now")
                            .font(.system(size: 16))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        }
    }

    // MARK: Text

    /// Keeps line breaks and turns **bold** into bold.
    static func formatted(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Safety path: real help, one tap away. Shown above Northstar's reply
/// whenever the brain says someone may be in crisis.
struct CrisisHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart")
                    .font(.system(size: 13, weight: .semibold))
                Text("YOU DON'T HAVE TO DO THIS ALONE")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
            }
            .foregroundStyle(NorthstarChatStyle.label)

            Text("Talk to someone now. It's free and confidential.")
                .font(.system(size: 17))
                .foregroundStyle(NorthstarChatStyle.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                helpLink("Call 988", systemImage: "phone.fill", url: "tel:988")
                helpLink("Text 988", systemImage: "message.fill", url: "sms:988")
            }

            Link(destination: URL(string: "tel:911")!) {
                Text("In danger right now? Call 911")
                    .font(.system(size: 15, weight: .semibold))
                    .underline()
                    .foregroundStyle(NorthstarChatStyle.text)
                    .frame(minHeight: 44)
            }

            Text("Outside the US? Call your local emergency number.")
                .font(.system(size: 14))
                .foregroundStyle(NorthstarChatStyle.soft)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.cardStrong))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }

    private func helpLink(_ title: String, systemImage: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NorthstarChatStyle.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
        }
    }
}

/// Small four-point star used on the stage chip.
struct NorthStarGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.08
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

/// Lays pills out in rows, wrapping to the next line when full.
struct PillFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Where an answer came from: small tappable site names under the reply.
struct SourcesRow: View {
    let sources: [NorthstarInsight.Source]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text("SOURCES").tracking(2)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            PillFlowLayout(spacing: 8) {
                ForEach(sources, id: \.self) { source in
                    Link(destination: source.url) {
                        HStack(spacing: 6) {
                            Text(source.site).lineLimit(1)
                            Image(systemName: "arrow.up.right").font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline)
                        .foregroundStyle(NorthstarChatStyle.soft)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(NorthstarChatStyle.card))
                        .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                    }
                    .accessibilityLabel("Source: \(source.title), \(source.site)")
                    .accessibilityHint("Opens in Safari")
                }
            }
        }
    }
}

/// "From before": a matching line from an earlier conversation.
/// Northstar only uses it if the person taps "Use this".
struct FromBeforeCard: View {
    let note: Note
    var canUse: Bool = true
    var onUse: (Note) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("FROM BEFORE").tracking(2)
                    Text("·")
                    Text(note.createdAt, format: .dateTime.month(.abbreviated).day())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)

                Text(note.text)
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .northstarReadingStyle()
                    .fixedSize(horizontal: false, vertical: true)

                if canUse {
                    HStack(spacing: 10) {
                        Button {
                            onUse(note)
                        } label: {
                            Text("Use this")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                        }
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
                        } label: {
                            Text("Not now")
                                .font(.body)
                                .foregroundStyle(NorthstarChatStyle.text)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
            .accessibilityElement(children: .contain)
    }
}

/// 🎯 "Keep this?" — Northstar offers to keep a new subject as one card that grows.
struct SubjectOfferCard: View {
    let offer: NorthstarInsight.SubjectOffer
    var state: String? = nil            // nil, "kept" or "dismissed" (kept by the chat)
    var onKeep: (NorthstarInsight.SubjectOffer) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    var body: some View {
        if state != "dismissed" {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                    Text("KEEP AS A SUBJECT?").tracking(2)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)

                Text(offer.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.text)
                if let goal = offer.goal, !goal.isEmpty {
                    Text(goal).font(.body).foregroundStyle(NorthstarChatStyle.soft)
                }
                if let next = offer.nextStep, !next.isEmpty {
                    Text("Next: \(next)").font(.subheadline).foregroundStyle(NorthstarChatStyle.label)
                }

                if state == "kept" {
                    Label("Kept. It will grow as you go.", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.savedGreen)
                } else {
                    if state == "keepFailed" {
                        Text("Couldn't keep it. Check your connection and try again.")
                            .font(.footnote)
                            .foregroundStyle(NorthstarChatStyle.soft)
                    }
                    HStack(spacing: 10) {
                        Button { onKeep(offer) } label: {
                            Text("Keep")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                        }
                        Button { withAnimation(.easeOut(duration: 0.2)) { onDismiss() } } label: {
                            Text("Not now")
                                .font(.body)
                                .foregroundStyle(NorthstarChatStyle.text)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
            .accessibilityElement(children: .contain)
        }
    }
}

/// "✓ Sunrise Loaf updated · Next: pick the name font · Undo"
struct SubjectUpdatedLine: View {
    let update: NorthstarInsight.SubjectUpdate
    var state: String? = nil            // nil, "undone", "changedSince" or "undoFailed"
    var onUndo: (NorthstarInsight.SubjectUpdate) -> Void = { _ in }

    private var undone: Bool { state == "undone" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: undone ? "arrow.uturn.backward" : "checkmark")
                Text(undone ? "\(update.title): change undone" : "\(update.title) updated")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if state == nil || state == "undoFailed" {
                    Button("Undo") { onUndo(update) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Undo the change to \(update.title)")
                }
            }
            .foregroundStyle(undone ? NorthstarChatStyle.label : NorthstarChatStyle.savedGreen)
            if state == "changedSince" {
                Text("The card changed after this, so it wasn't undone. Open it in Search to edit.")
                    .font(.footnote).foregroundStyle(NorthstarChatStyle.soft)
            } else if state == "undoFailed" {
                Text("Couldn't undo. Check your connection and try again.")
                    .font(.footnote).foregroundStyle(NorthstarChatStyle.soft)
            }
            if !undone {
                ForEach(update.changes, id: \.self) { change in
                    Text(change).font(.footnote).foregroundStyle(NorthstarChatStyle.soft)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
