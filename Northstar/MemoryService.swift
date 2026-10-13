import Foundation
import Supabase

final class MemoryService {

    private let client =
        SupabaseManager.shared.client

    // MARK: Save Memory

    @discardableResult
    func saveMemory(
        identityId: UUID,
        projectId: UUID?,
        content: String,
        category: String? = nil
    ) async throws -> UUID {

        let id = UUID()

        try await client
            .from("memories")
            .insert([
                "id":
                    id.uuidString,

                "identity_id":
                    identityId.uuidString,

                "project_id":
                    projectId?.uuidString,

                "content":
                    content,

                "category":
                    category ?? ""
            ])
            .execute()

        return id
    }

    // MARK: Load Memories

    func loadMemories(
        identityId: UUID
    ) async throws -> [Memory] {

        let memories: [Memory] =
            try await client
                .from("memories")
                .select()
                .eq(
                    "identity_id",
                    value:
                        identityId.uuidString
                )
                .order(
                    "created_at",
                    ascending: false
                )
                .execute()
                .value

        return memories
    }

    // MARK: Delete Memory

    func deleteMemory(
        id: UUID
    ) async throws {

        try await client
            .from("memories")
            .delete()
            .eq(
                "id",
                value: id.uuidString
            )
            .execute()
    }
}
