import Foundation
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

    /// Makes the clip and returns a link to play it. Throws a friendly message if it can't.
    func make(prompt: String, seconds: Int) async throws -> URL {
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
                if let url = check.url { return url }
                throw VideoError.message("The video is ready but couldn't be opened.")
            case "failed":
                throw VideoError.message(check.error ?? "The video didn't work.")
            default:
                continue
            }
        }
        throw VideoError.message("This is taking longer than usual. Please try again later.")
    }

    /// Deletes all of this person's clips (files and records). Part of "Delete all".
    func deleteAll() async throws {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let folder = userId.uuidString.lowercased()
        let files = try await client.storage.from("videos").list(path: folder)
        let paths = files.map { "\(folder)/\($0.name)" }
        if !paths.isEmpty { _ = try await client.storage.from("videos").remove(paths: paths) }
        try await client.from("video_jobs").delete().eq("user_id", value: userId.uuidString).execute()
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
