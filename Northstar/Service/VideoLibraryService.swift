import Foundation
import Supabase

// 🎬 Videos library: the person's folders (folders inside folders) and the videos they saved.
// YouTube videos are kept as a link; videos they made are kept as the real file in private storage.
// Row-level security: everyone only ever sees and changes their own.

nonisolated struct VideoFolder: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let parentId: UUID?
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case parentId = "parent_id"
    }
}

nonisolated struct SavedVideo: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let folderId: UUID?
    let title: String
    let source: String        // "youtube" | "made"
    let youtubeId: String?
    let storagePath: String?

    enum CodingKeys: String, CodingKey {
        case id, title, source
        case folderId = "folder_id"
        case youtubeId = "youtube_id"
        case storagePath = "storage_path"
    }

    var isYouTube: Bool { source == "youtube" }
}

/// Something that can be saved: a YouTube lesson or a video made in Northstar.
nonisolated enum VideoToSave: Hashable, Sendable {
    case youtube(id: String, title: String)
    case made(storagePath: String, title: String)
}

struct VideoLibraryService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    nonisolated private struct NewFolder: Encodable, Sendable { let name: String; let parent_id: UUID? }
    nonisolated private struct Rename: Encodable, Sendable { let name: String }
    nonisolated private struct MoveFolder: Encodable, Sendable { let parent_id: UUID? }
    nonisolated private struct MoveVideo: Encodable, Sendable { let folder_id: UUID? }
    nonisolated private struct RenameVideo: Encodable, Sendable { let title: String }
    nonisolated private struct NewVideo: Encodable, Sendable {
        let folder_id: UUID?
        let title: String
        let source: String
        let youtube_id: String?
        let storage_path: String?
    }

    // MARK: Folders

    func folders() async throws -> [VideoFolder] {
        try await client.from("video_folders").select("id, parent_id, name").order("name").execute().value
    }

    func createFolder(name: String, parent: UUID?) async throws -> VideoFolder {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        return try await client.from("video_folders")
            .insert(NewFolder(name: clean.isEmpty ? "New folder" : clean, parent_id: parent))
            .select("id, parent_id, name").single().execute().value
    }

    func renameFolder(_ id: UUID, to name: String) async throws {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !clean.isEmpty else { return }
        try await client.from("video_folders").update(Rename(name: clean)).eq("id", value: id.uuidString).execute()
    }

    func moveFolder(_ id: UUID, into parent: UUID?) async throws {
        try await client.from("video_folders").update(MoveFolder(parent_id: parent)).eq("id", value: id.uuidString).execute()
    }

    /// Deletes the folder and everything inside it.
    func deleteFolder(_ id: UUID) async throws {
        try await client.from("video_folders").delete().eq("id", value: id.uuidString).execute()
    }

    /// The folder with this name at the top level, created if it doesn't exist yet.
    func folderNamed(_ name: String) async throws -> VideoFolder {
        let all = try await folders()
        if let found = all.first(where: { $0.parentId == nil && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return found
        }
        return try await createFolder(name: name, parent: nil)
    }

    // MARK: Videos

    func videos() async throws -> [SavedVideo] {
        try await client.from("saved_videos")
            .select("id, folder_id, title, source, youtube_id, storage_path")
            .order("created_at", ascending: false)
            .execute().value
    }

    func save(_ video: VideoToSave, in folder: UUID?) async throws {
        let row: NewVideo
        switch video {
        case let .youtube(id, title):
            row = NewVideo(folder_id: folder, title: String(title.prefix(200)), source: "youtube", youtube_id: id, storage_path: nil)
        case let .made(path, title):
            row = NewVideo(folder_id: folder, title: String(title.prefix(200)), source: "made", youtube_id: nil, storage_path: path)
        }
        try await client.from("saved_videos").insert(row).execute()
    }

    func moveVideo(_ id: UUID, into folder: UUID?) async throws {
        try await client.from("saved_videos").update(MoveVideo(folder_id: folder)).eq("id", value: id.uuidString).execute()
    }

    func renameVideo(_ id: UUID, to title: String) async throws {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !clean.isEmpty else { return }
        try await client.from("saved_videos").update(RenameVideo(title: clean)).eq("id", value: id.uuidString).execute()
    }

    func deleteVideo(_ id: UUID) async throws {
        try await client.from("saved_videos").delete().eq("id", value: id.uuidString).execute()
    }

    /// A short-lived link to play a video the person made.
    func playURL(for video: SavedVideo) async throws -> URL? {
        if let id = video.youtubeId { return URL(string: "https://www.youtube.com/watch?v=\(id)") }
        guard let path = video.storagePath else { return nil }
        return try await client.storage.from("videos").createSignedURL(path: path, expiresIn: 3600)
    }

    /// "Wood carving › Spoons" for a folder.
    nonisolated static func path(of folder: VideoFolder, in all: [VideoFolder]) -> String {
        var names = [folder.name]
        var parent = folder.parentId
        var guardCount = 0
        while let p = parent, let f = all.first(where: { $0.id == p }), guardCount < 20 {
            names.insert(f.name, at: 0)
            parent = f.parentId
            guardCount += 1
        }
        return names.joined(separator: " › ")
    }
}
