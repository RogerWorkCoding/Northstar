import Foundation
import Supabase

// Subjects: the person's kept projects, one card each that grows over time.
// The brain offers new ones ("Keep this?") and updates kept ones right away;
// the app keeps them, shows them, and can undo an update. Row-level security
// means every call only touches the signed-in person's own subjects.

nonisolated struct SubjectDecision: Codable, Hashable, Sendable {
    let text: String
    let at: String          // "2026-10-13"
}

nonisolated struct Subject: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let title: String
    let goal: String?
    let nextStep: String?
    let decisions: [SubjectDecision]
    let status: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, goal, decisions, status
        case nextStep = "next_step"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        goal = try c.decodeIfPresent(String.self, forKey: .goal)
        nextStep = try c.decodeIfPresent(String.self, forKey: .nextStep)
        decisions = (try? c.decodeIfPresent([SubjectDecision].self, forKey: .decisions)) ?? []
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "active"
        updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct SubjectsService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    nonisolated private struct NewSubject: Encodable, Sendable {
        let title: String
        let goal: String?
        let next_step: String?
    }

    nonisolated private struct Restore: Encodable, Sendable {
        let goal: String?
        let next_step: String?
        let decisions: [SubjectDecision]
        let status: String
        let updated_at: String
    }

    nonisolated private struct StatusOnly: Encodable, Sendable {
        let status: String
        let updated_at: String
    }

    /// Active subjects, most recently updated first.
    func active() async throws -> [Subject] {
        try await client.from("subjects")
            .select("id, title, goal, next_step, decisions, status, updated_at")
            .eq("status", value: "active")
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    /// "Keep" on an offer: the subject is saved (only what the person confirmed).
    /// If an active subject with this title already exists, it counts as kept.
    func keep(title: String, goal: String?, nextStep: String?) async throws {
        do {
            try await client.from("subjects")
                .insert(NewSubject(title: title, goal: goal, next_step: nextStep))
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {
            return // already kept
        }
    }

    nonisolated private struct IdRow: Decodable, Sendable { let id: UUID }

    /// Undo an automatic update: put the card back the way it was, but only if it
    /// hasn't changed since (so a later update is never wiped). Returns false if it had.
    func undo(_ update: NorthstarInsight.SubjectUpdate) async throws -> Bool {
        let before = update.undo
        let rows: [IdRow] = try await client.from("subjects")
            .update(Restore(goal: before.goal, next_step: before.nextStep, decisions: before.decisions,
                            status: before.status, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: update.id.uuidString)
            .eq("updated_at", value: update.stamp)
            .select("id")
            .execute()
            .value
        return !rows.isEmpty
    }

    func markDone(id: UUID) async throws {
        try await client.from("subjects")
            .update(StatusOnly(status: "done", updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client.from("subjects").delete().eq("id", value: id.uuidString).execute()
    }

    /// Every subject (active and done), for Export.
    func all() async throws -> [Subject] {
        try await client.from("subjects")
            .select("id, title, goal, next_step, decisions, status, updated_at")
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func deleteAll() async throws {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        try await client.from("subjects").delete().eq("user_id", value: userId.uuidString).execute()
    }
}
