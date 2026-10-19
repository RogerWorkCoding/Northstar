import SwiftUI

// ✦ Discovery panel: a result that grows from the bottom of Discovery, on the same screen.
// Discovery and Chat are different experiences (docs/discovery-and-chat.md): "find" and "answer" paths are
// solved here, in place. Chat opens only when the person taps "Discuss in Chat".
//   • find   → real local providers (the Home & Services results, reused as-is).
//   • answer → a short, focused answer from the brain (source "discovery").

enum DiscoveryPanelContent: Equatable {
    case find(need: String)
    case answer(title: String, prompt: String)
    case connections        // from the star: connect apps, right here
    case brain              // from the star: how hard Northstar thinks
}

/// Owns what the panel shows. Each open bumps a generation number, so a slow earlier answer can never
/// replace the one the person picked after it.
@MainActor @Observable
final class DiscoveryPanelModel {
    enum Status: Equatable { case closed, loading, loaded, empty, failed }

    private(set) var status: Status = .closed
    private(set) var content: DiscoveryPanelContent?
    private(set) var selectedId: String?
    private(set) var title = ""
    private(set) var providers: HomeServicesState = .loading
    private(set) var answerText = ""
    /// The brain recognised a crisis in an answer: Discovery hands over to crisis help.
    private(set) var crisis = false

    private var request = ""
    private var generation = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    private let engine = NorthstarEngineClient()

    var isOpen: Bool { status != .closed }

    func open(_ content: DiscoveryPanelContent, id: String, title: String, request: String) {
        task?.cancel()
        generation += 1
        let mine = generation
        self.content = content
        self.selectedId = id
        self.title = title
        self.request = request
        status = .loading
        providers = .loading
        answerText = ""
        if content == .connections || content == .brain {
            status = .loaded     // nothing to load: the choices show at once
            return
        }
        AccessibilityNotification.Announcement("Loading \(title)").post()
        task = Task { [weak self] in await self?.load(content, request: request, generation: mine) }
    }

    func retry() {
        guard let content, let selectedId else { return }
        open(content, id: selectedId, title: title, request: request)
    }

    /// Closing also cancels whatever was still loading.
    func close() {
        task?.cancel()
        task = nil
        generation += 1
        status = .closed
        content = nil
        selectedId = nil
        crisis = false
    }

    private func load(_ content: DiscoveryPanelContent, request: String, generation mine: Int) async {
        switch content {
        case .find(let need):
            let result = await HomeServicesProviderService.recommend(need: need)
            guard mine == generation, !Task.isCancelled else { return }
            providers = result
            switch result {
            case .ready: status = .loaded
            case .noProviders: status = .empty
            case .loading: return
            default: status = .failed
            }
        case .connections, .brain:
            return
        case .answer(_, let prompt):
            let ask = "\(prompt)\n\nWhat I wrote: \(request)"
            // "What's on my calendar?" answered right here, from their real calendar (only if they connected it).
            let calendar = NorthstarCalendar.asksAboutSchedule(request) ? await NorthstarCalendar.shared.upcoming() : nil
            let reply = await engine.getReply(for: [MessageModel(role: .user, content: ask)],
                                              settings: EngineSettings.current, calendar: calendar, source: "discovery")
            guard mine == generation, !Task.isCancelled else { return }
            if reply.insight?.crisis == true { crisis = true }
            answerText = reply.failed ? "" : reply.text
            status = reply.failed ? .failed : .loaded
        }
        let said: String = switch status {
        case .loaded: "\(title) is ready"
        case .empty: "Nothing found for \(title)"
        case .failed: "Couldn't load \(title). Try again is available."
        default: ""
        }
        if !said.isEmpty { AccessibilityNotification.Announcement(said).post() }
    }

    /// What Chat starts with when the person taps "Discuss in Chat": only what the panel really showed.
    func chatOpener() -> String {
        switch content {
        case .some(.answer) where status == .loaded && !answerText.isEmpty:
            return "Here's what I put together for \u{201C}\(title)\u{201D}:\n\n\(answerText)\n\nWhat would you like to talk through?"
        case .some(.find(let need)):
            if case .ready(let rec) = providers, let top = rec.recommended {
                let line = { (p: HomeServiceProvider) -> String in
                    guard let s = p.sources.first else { return "\u{2022} \(p.name)" }
                    return "\u{2022} \(p.name): \(String(format: "%.1f", s.rating)) on \(s.name) (\(s.count) reviews)"
                }
                let list = ([top] + rec.alternatives).map(line).joined(separator: "\n")
                return "Here are the \(need) options I found near you:\n\(list)\n\nWhat would you like to talk through?"
            }
            return "Let's talk about finding a \(need). What matters most to you?"
        default:
            return "Let's talk about \(title.lowercased()). What would help most?"
        }
    }
}

/// The panel itself: one scroll area, then "Back to suggestions" and a quieter "Discuss in Chat".
struct DiscoveryPanelView: View {
    let model: DiscoveryPanelModel
    var onBack: () -> Void
    var onChat: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(model.title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)

            footer
        }
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(red: 0.06, green: 0.08, blue: 0.18).opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.title) result")
    }

    @ViewBuilder
    private var content: some View {
        switch model.content {
        case .some(.find(let need)):
            HomeServicesResultsView(need: need, state: model.providers) { model.retry() }
        case .some(.answer):
            switch model.status {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Working on it\u{2026}").foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            case .failed, .empty:
                VStack(alignment: .leading, spacing: 10) {
                    Text("I couldn't get an answer right now.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                    Button("Try again") { model.retry() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.55))
                        .frame(minHeight: 44)
                }
            default:
                Text(NorthstarReplyView.formatted(model.answerText))
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .tint(Color(red: 0.62, green: 0.75, blue: 1.0))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        case .some(.connections):
            ConnectionsPanelContent()
        case .some(.brain):
            BrainLevelPanelContent()
        case nil:
            EmptyView()
        }
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { backButton; chatButton }
            VStack(spacing: 8) { backButton; chatButton }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Label("Back to suggestions", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.06, green: 0.08, blue: 0.18))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(.white.opacity(0.92)))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Closes this result and shows the suggestions again")
    }

    /// Secondary on purpose: Chat is a choice, never the automatic next step. Hidden while loading.
    @ViewBuilder
    private var chatButton: some View {
        if model.status != .loading, model.content != .connections, model.content != .brain {
            Button(action: onChat) {
                Label("Discuss in Chat", systemImage: "bubble.left.and.bubble.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a chat that starts from this result")
        }
    }
}
