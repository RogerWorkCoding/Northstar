import Foundation
import AVKit
import Supabase

// Makes a short video from a shot card's prompt with Google Veo (through the
// northstar-video function; the Google key never touches the app).
// Start a job, then check every few seconds until it's done (usually under a few minutes).

nonisolated struct VideoStatus: Decodable, Sendable {
    let status: String?      // "working" | "done" | "failed"
    let jobId: String?
    let url: URL?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case status, url, error
        case jobId = "job_id"
    }
}

nonisolated enum VideoError: LocalizedError, Sendable {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

struct VideoService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    nonisolated private struct StartRequest: Encodable, Sendable {
        let action = "start"
        let prompt: String
        let seconds: Int
    }
    nonisolated private struct CheckRequest: Encodable, Sendable {
        let action = "check"
        let job_id: String
    }

    /// Makes the clip, saves it on the phone (Documents/Videos) and returns the file.
    /// Throws a friendly message if it can't.
    func make(prompt: String, seconds: Int) async throws -> (file: URL, storagePath: String) {
        let (jobId, remote) = try await makeRemote(prompt: prompt, seconds: seconds)
        let file = try await saveLocally(remote, name: jobId)
        let user = SupabaseManager.shared.currentUserId?.uuidString.lowercased() ?? ""
        return (file, "\(user)/\(jobId.lowercased()).mp4")
    }

    private func makeRemote(prompt: String, seconds: Int) async throws -> (String, URL) {
        let started = try await call(StartRequest(prompt: prompt, seconds: seconds))
        guard let jobId = started.jobId else {
            throw VideoError.message(started.error ?? "Couldn't start the video.")
        }
        // Check every 5 seconds, for up to about 7 minutes.
        for _ in 0..<84 {
            try await Task.sleep(for: .seconds(5))
            let check = try await call(CheckRequest(job_id: jobId))
            switch check.status {
            case "done":
                if let url = check.url { return (jobId, url) }
                throw VideoError.message("The video is ready but couldn't be opened.")
            case "failed":
                throw VideoError.message(check.error ?? "The video didn't work.")
            default:
                continue
            }
        }
        throw VideoError.message("This is taking longer than usual. Please try again later.")
    }

    /// Keeps a copy on the phone, so it plays any time and can be saved or shared as a file.
    private func saveLocally(_ remote: URL, name: String) async throws -> URL {
        let (temp, response) = try await URLSession.shared.download(from: remote)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw VideoError.message("The video is ready but couldn't be downloaded.")
        }
        let folder = URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "Northstar-\(name.prefix(8)).mp4")
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: temp, to: file)
        return file
    }

    /// Deletes all of this person's clips (files and records). Part of "Delete all".
    func deleteAll() async throws {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let folder = userId.uuidString.lowercased()
        let files = try await client.storage.from("videos").list(path: folder, options: SearchOptions(limit: 1000))
        let paths = files.map { "\(folder)/\($0.name)" }
        if !paths.isEmpty { _ = try await client.storage.from("videos").remove(paths: paths) }
        try await client.from("video_jobs").delete().eq("user_id", value: userId.uuidString).execute()
        // And the copies on this phone.
        let local = URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: local)
    }

    private func call<Body: Encodable & Sendable>(_ body: Body) async throws -> VideoStatus {
        do {
            return try await client.functions.invoke("northstar-video", options: FunctionInvokeOptions(body: body))
        } catch let FunctionsError.httpError(_, data) {
            // Limits and Google errors come back with a friendly message.
            let reply = try? JSONDecoder().decode(VideoStatus.self, from: data)
            throw VideoError.message(reply?.error ?? "Couldn't make the video right now.")
        }
    }
}

/// Keeps video jobs alive while the chat scrolls (a card can leave the screen and come back).
/// Keyed by the shot's prompt. Several shots can be made at once for a full video.
@MainActor
@Observable
final class VideoStore {
    static let shared = VideoStore()

    private(set) var files: [String: URL] = [:]
    private(set) var problems: [String: String] = [:]
    /// Shots being made right now.
    private(set) var making: Set<String> = []
    /// Where each made video is kept in storage (for saving it to the Videos library).
    private(set) var storagePaths: [String: String] = [:]
    /// Full videos (all the shots joined), keyed by their shots' prompts.
    private(set) var films: [String: URL] = [:]
    private(set) var filmProblems: [String: String] = [:]
    private(set) var makingFilm: String?
    @ObservationIgnored private var players: [String: AVPlayer] = [:]

    private let service = VideoService()
    private init() {}

    var busy: Bool { !making.isEmpty || makingFilm != nil }

    func player(for prompt: String) -> AVPlayer? {
        guard let file = files[prompt] else { return nil }
        if let existing = players[prompt] { return existing }
        let player = AVPlayer(url: file)
        players[prompt] = player
        return player
    }

    func filmPlayer(for key: String) -> AVPlayer? {
        guard let file = films[key] else { return nil }
        if let existing = players["film:" + key] { return existing }
        let player = AVPlayer(url: file)
        players["film:" + key] = player
        return player
    }

    static func filmKey(_ shots: [NorthstarInsight.Shot]) -> String {
        shots.map(\.prompt).joined(separator: "\u{1F}")
    }

    func make(prompt: String, seconds: Int) {
        guard !busy, files[prompt] == nil else { return }
        Task { await makeOne(prompt: prompt, seconds: seconds) }
    }

    private func makeOne(prompt: String, seconds: Int) async {
        guard files[prompt] == nil, !making.contains(prompt) else { return }
        problems[prompt] = nil
        making.insert(prompt)
        do {
            let made = try await service.make(prompt: prompt, seconds: seconds)
            storagePaths[prompt] = made.storagePath
            files[prompt] = made.file
        } catch {
            problems[prompt] = error.localizedDescription
        }
        making.remove(prompt)
    }

    /// 🎬 Full video: makes every shot that isn't made yet (all at once), then joins them in order.
    func makeFilm(_ shots: [NorthstarInsight.Shot]) {
        let key = Self.filmKey(shots)
        guard !busy, films[key] == nil, shots.count >= 2 else { return }
        filmProblems[key] = nil
        makingFilm = key
        Task {
            await withTaskGroup(of: Void.self) { group in
                for shot in shots where files[shot.prompt] == nil {
                    let prompt = shot.prompt, seconds = shot.seconds
                    group.addTask { await self.makeOne(prompt: prompt, seconds: seconds) }
                }
            }
            let clips = shots.compactMap { files[$0.prompt] }
            if clips.count == shots.count {
                do {
                    films[key] = try await FilmJoiner.join(clips)
                } catch {
                    filmProblems[key] = "The shots are made, but joining them didn't work. You can still play each one below."
                }
            } else {
                filmProblems[key] = shots.compactMap { problems[$0.prompt] }.first
                    ?? "Some shots didn't work. Try again, or make them one at a time."
            }
            makingFilm = nil
        }
    }
}

/// Joins clips one after another into a single video on the phone (no extra cost).
enum FilmJoiner {
    static func join(_ clips: [URL]) async throws -> URL {
        let film = AVMutableComposition()
        guard let video = film.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoError.message("Couldn't join the shots.")
        }
        let audio = film.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var at = CMTime.zero
        for url in clips {
            let asset = AVURLAsset(url: url)
            let length = try await asset.load(.duration)
            let range = CMTimeRange(start: .zero, duration: length)
            if let v = try await asset.loadTracks(withMediaType: .video).first {
                try video.insertTimeRange(range, of: v, at: at)
                if at == .zero { video.preferredTransform = try await v.load(.preferredTransform) }
            }
            if let a = try await asset.loadTracks(withMediaType: .audio).first {
                try audio?.insertTimeRange(range, of: a, at: at)
            }
            at = CMTimeAdd(at, length)
        }
        guard let export = AVAssetExportSession(asset: film, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoError.message("Couldn't join the shots.")
        }
        let folder = URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "Northstar-film-\(UUID().uuidString.prefix(8)).mp4")
        try await export.export(to: file, as: .mp4)
        return file
    }
}
