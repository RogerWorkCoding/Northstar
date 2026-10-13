import Foundation
import Supabase

// Notes: one-liners Northstar keeps from chats, so you can find them later.
// The brain keeps them (never feelings or health, never when memory is off).
// The app only searches, deletes, and exports them. Row-level security means
// every call only ever touches the signed-in person's own notes.

nonisolated struct Note: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let text: String          // what you said, one line
    let context: String?      // what Northstar answered (short)
    let subject: String?      // the goal it belongs to, if any
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, text, context, subject
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        context = try c.decodeIfPresent(String.self, forKey: .context)
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        // Postgres sends dates with or without fractional seconds.
        let raw = try c.decode(String.self, forKey: .createdAt)
        createdAt = Note.parseDate(raw) ?? Date()
    }

    private static func parseDate(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}

struct NotesService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private struct SearchRequest: Encodable, Sendable { let query: String; let limit: Int }
    private struct SearchReply: Decodable, Sendable { let results: [Note]?; let error: String? }

    /// Find notes by a word or a sentence (by words and by meaning).
    func search(_ query: String, limit: Int = 30) async throws -> [Note] {
        let reply: SearchReply = try await client.functions.invoke(
            "northstar-search",
            options: FunctionInvokeOptions(body: SearchRequest(query: query, limit: limit))
        )
        if let error = reply.error { throw NSError(domain: "Northstar", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
        return reply.results ?? []
    }

    /// The most recent notes (for Export).
    func recent(limit: Int = 500) async throws -> [Note] {
        try await client.from("notes")
            .select("id, text, context, subject, created_at")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await client.from("notes").delete().eq("id", value: id.uuidString).execute()
    }

    /// Deletes every note. Row-level security limits this to the person's own.
    func deleteAll() async throws {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        try await client.from("notes").delete().eq("user_id", value: userId.uuidString).execute()
    }
}
