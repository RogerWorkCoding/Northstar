import Foundation
import Supabase

// Saved chats: kept so History can list them and a search result can open the
// chat it came from. Only kept when memory is on. Row-level security means
// every call only touches the signed-in person's own chats.

nonisolated struct ChatSummary: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let title: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        updatedAt = ChatsService.parseDate(try c.decode(String.self, forKey: .updatedAt)) ?? Date()
    }
}

nonisolated struct StoredMessage: Hashable, Sendable, Decodable {
    let role: String
    let content: String
}

struct ChatsService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    nonisolated private struct NewChat: Encodable, Sendable {
        let id: UUID
        let title: String
    }

    nonisolated private struct NewMessage: Encodable, Sendable {
        let chat_id: UUID
        let role: String
        let content: String
        let created_at: String
    }

    nonisolated private struct Rename: Encodable, Sendable {
        let title: String
    }

    /// Gives a chat the short name Northstar suggested on its first reply.
    func rename(chatId: UUID, to title: String) async throws {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !clean.isEmpty else { return }
        try await client.from("chats").update(Rename(title: clean)).eq("id", value: chatId.uuidString).execute()
    }

    nonisolated private struct Touch: Encodable, Sendable {
        let updated_at: String
    }

    /// Starts a saved chat, named after its first message.
    func create(firstMessage: String) async throws -> UUID {
        let id = UUID()
        try await client.from("chats")
            .insert(NewChat(id: id, title: Self.title(from: firstMessage)))
            .execute()
        return id
    }

    /// Saves one exchange (what they said, what Northstar answered), in order.
    func append(chatId: UUID, user: String, assistant: String) async throws {
        let now = Date()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows = [
            NewMessage(chat_id: chatId, role: "user", content: Self.limit(user),
                       created_at: iso.string(from: now)),
            NewMessage(chat_id: chatId, role: "assistant", content: Self.limit(assistant),
                       created_at: iso.string(from: now.addingTimeInterval(0.001))),
        ].filter { !$0.content.isEmpty }
        try await client.from("chat_messages").insert(rows).execute()
        try await client.from("chats")
            .update(Touch(updated_at: iso.string(from: now)))
            .eq("id", value: chatId.uuidString)
            .execute()
    }

    /// Newest first.
    func list(limit: Int = 100) async throws -> [ChatSummary] {
        try await client.from("chats")
            .select("id, title, updated_at")
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func messages(chatId: UUID) async throws -> [StoredMessage] {
        try await client.from("chat_messages")
            .select("role, content")
            .eq("chat_id", value: chatId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await client.from("chats").delete().eq("id", value: id.uuidString).execute()
    }

    func deleteAll() async throws {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        try await client.from("chats").delete().eq("user_id", value: userId.uuidString).execute()
    }

    /// "I'm starting a vegetable garden this spring. First…" → "I'm starting a vegetable garden this spring"
    nonisolated static func title(from text: String) -> String {
        let firstLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sentence = firstLine.split(whereSeparator: { ".?!".contains($0) }).first.map(String.init) ?? firstLine
        var title = sentence.trimmingCharacters(in: .whitespaces)
        if title.count > 60 {
            title = String(title.prefix(60))
            if let space = title.lastIndex(of: " ") { title = String(title[..<space]) }
            title += "…"
        }
        return title.isEmpty ? "Chat" : title
    }

    /// At most 8000 Unicode code points (the database counts these, not visible letters).
    nonisolated static func limit(_ s: String) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: s.unicodeScalars.prefix(8000))
        return String(view)
    }

    nonisolated static func parseDate(_ s: String) -> Date? {
        let a = ISO8601DateFormatter()
        a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = a.date(from: s) { return d }
        let b = ISO8601DateFormatter()
        b.formatOptions = [.withInternetDateTime]
        return b.date(from: s)
    }
}
