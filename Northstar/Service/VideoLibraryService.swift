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

/// A video the person made in Northstar (saved to Videos or not): Video history.
nonisolated struct MadeVideo: Identifiable, Hashable, Sendable {
    let id: UUID
    let prompt: String
    let seconds: Int
    let storagePath: String
    let createdAt: String

    /// A short name from the prompt: its first sentence, up to about 60 characters.
    var title: String {
        let first = prompt.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? prompt
        let clean = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count <= 60 { return clean.isEmpty ? "Video" : clean }
        let cut = clean.prefix(60)
        return (cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)) + "…"
    }

    /// "Today 6:04 PM", "Yesterday 7:34 PM" or "Oct 13".
    var when: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = iso.date(from: createdAt) ?? plain.date(from: createdAt) else { return "" }
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Today \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday \(time)" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
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

    /// Makes a folder — or returns the one already there with that name in that place.
    func createFolder(name: String, parent: UUID?) async throws -> VideoFolder {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        let clean = trimmed.isEmpty ? "New folder" : trimmed
        func existing() async throws -> VideoFolder? {
            try await folders().first { $0.parentId == parent && $0.name.caseInsensitiveCompare(clean) == .orderedSame }
        }
        if let found = try await existing() { return found }
        do {
            return try await client.from("video_folders")
                .insert(NewFolder(name: clean, parent_id: parent))
                .select("id, parent_id, name").single().execute().value
        } catch {
            // Made at the same moment by another card or device: use that one.
            if let found = try await existing() { return found }
            throw error
        }
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
        try await createFolder(name: name, parent: nil)
    }

    /// Settings → Delete all: every folder and saved video.
    func deleteAll() async throws {
        guard let user = SupabaseManager.shared.currentUserId else { return }
        try await client.from("saved_videos").delete().eq("user_id", value: user.uuidString).execute()
        try await client.from("video_folders").delete().eq("user_id", value: user.uuidString).execute()
    }

    // MARK: Videos

    func videos() async throws -> [SavedVideo] {
        try await client.from("saved_videos")
            .select("id, folder_id, title, source, youtube_id, storage_path")
            .order("created_at", ascending: false)
            .execute().value
    }

    /// Saves a video, or moves it if it's already saved (each video is kept once).
    func save(_ video: VideoToSave, in folder: UUID?) async throws {
        if let already = try await existing(video) {
            try await moveVideo(already.id, into: folder)
            return
        }
        let row: NewVideo
        switch video {
        case let .youtube(id, title):
            row = NewVideo(folder_id: folder, title: String(title.prefix(200)), source: "youtube", youtube_id: id, storage_path: nil)
        case let .made(path, title):
            row = NewVideo(folder_id: folder, title: String(title.prefix(200)), source: "made", youtube_id: nil, storage_path: path)
        }
        try await client.from("saved_videos").insert(row).execute()
    }

    /// The saved copy of this video, if it was saved before.
    func existing(_ video: VideoToSave) async throws -> SavedVideo? {
        let base = client.from("saved_videos").select("id, folder_id, title, source, youtube_id, storage_path")
        let rows: [SavedVideo]
        switch video {
        case let .youtube(id, _): rows = try await base.eq("youtube_id", value: id).limit(1).execute().value
        case let .made(path, _): rows = try await base.eq("storage_path", value: path).limit(1).execute().value
        }
        return rows.first
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

    // MARK: Video history

    /// Every video the person made that finished (newest first), saved to Videos or not,
    /// so a paid video is never lost if the app closes before Save is tapped.
    func madeVideos() async throws -> [MadeVideo] {
        let rows: [MadeRow] = try await client.from("video_jobs")
            .select("id, prompt, seconds, storage_path, created_at")
            .eq("status", value: "done")
            .order("created_at", ascending: false)
            .limit(200)
            .execute().value
        return rows.compactMap { row in
            row.storage_path.map { MadeVideo(id: row.id, prompt: row.prompt, seconds: row.seconds, storagePath: $0, createdAt: row.created_at) }
        }
    }

    nonisolated private struct MadeRow: Decodable, Sendable {
        let id: UUID
        let prompt: String
        let seconds: Int
        let storage_path: String?
        let created_at: String
    }

    /// A short-lived link to play a made video straight from its file.
    func playURL(storagePath path: String) async throws -> URL {
        try await client.storage.from("videos").createSignedURL(path: path, expiresIn: 3600)
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
