import SwiftUI

struct ChatBubbleView: View {

    let id: UUID
    let text: String
    let isUser: Bool

    init(id: UUID, text: String, isUser: Bool) {
        self.id = id
        self.text = text
        self.isUser = isUser
    }

    var body: some View {
        if let response = structuredResponse {
            NorthstarResponseContainer(isUser: isUser, density: response.density) {
                NorthstarStructuredResponseView(response: response)
            }
        } else {
            plainBubble
        }
    }

    /// Only assistant replies get the editorial treatment, and only once they clear
    /// .compact — short/plain content keeps the original conversational pill untouched.
    /// Internal (not private) so NorthstarTests can exercise this decision directly.
    var structuredResponse: NorthstarStructuredResponse? {
        guard !isUser else { return nil }
        let response = NorthstarResponseParseCache.shared.response(for: id, content: text)
        guard response.hasStructure, response.density != .compact else { return nil }
        return response
    }

    /// Unchanged from the original implementation: the exact fallback path for user
    /// messages, short replies, and anything the parser can't find structure in.
    private var plainBubble: some View {
        HStack {
            if isUser {
                Spacer(minLength: 60)
            }

            Text(text)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(0.35)
                )
            )

            if !isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Per-message parse cache so NorthstarResponseParser runs once per (id, content) pair
/// instead of on every SwiftUI re-render. Entries live as long as the owning ChatViewModel,
/// the same lifetime as the message list itself, so there's nothing extra to evict.
@MainActor
final class NorthstarResponseParseCache {
    static let shared = NorthstarResponseParseCache()

    private struct Entry {
        let contentHash: Int
        let response: NorthstarStructuredResponse
    }

    private var storage: [UUID: Entry] = [:]

    private init() {}

    func response(for id: UUID, content: String) -> NorthstarStructuredResponse {
        let hash = content.hashValue
        if let entry = storage[id], entry.contentHash == hash {
            return entry.response
        }
        let parsed = NorthstarResponseParser.parse(content)
        storage[id] = Entry(contentHash: hash, response: parsed)
        return parsed
    }
}

#Preview("Short — compact") {
    VStack(spacing: 20) {
        ChatBubbleView(id: UUID(), text: "Create a sitemap", isUser: true)
        ChatBubbleView(id: UUID(), text: "Sure — I'll put together a sitemap for your site now.", isUser: false)
    }
    .padding()
    .background(Color(red: 0.08, green: 0.12, blue: 0.25))
}

#Preview("Medium — standard") {
    ChatBubbleView(
        id: UUID(),
        text: """
        ## Sitemap Draft

        Here's a starting structure for your site.

        - Home
        - Services
        - Portfolio
        """,
        isUser: false
    )
    .padding()
    .background(Color(red: 0.08, green: 0.12, blue: 0.25))
}

#Preview("Large — expanded") {
    ChatBubbleView(
        id: UUID(),
        text: """
        Labels: Foundation, Memory, Architecture

        Project Memory keeps continuity across every session.

        ## How Northstar Remembers

        Northstar blends three memory layers so guidance stays relevant as a project evolves.

        ## Foundation

        - **Project Memory** stores goals, progress, blockers, and the current stage.
        - **Identity Memory** captures voice, tone, and recurring preferences.

        ## Architecture

        Each layer is written independently and merged only at response time.

        - Reads happen before every reply.
        - Writes happen only after explicit confirmation.

        ## Next Recommended Action

        Review your Project Memory entry to confirm the current stage still matches reality.
        """,
        isUser: false
    )
    .padding()
    .background(Color(red: 0.08, green: 0.12, blue: 0.25))
}
