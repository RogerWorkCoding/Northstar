import Foundation
import AppKit
import Observation

/// One request from the iPhone and what this Mac did with it.
struct DoneTask: Identifiable {
    let id: String
    let request: String
    let say: String
    let files: [FoundFile]
    let when: Date
    var failed: String? = nil
}

@MainActor
@Observable
final class NavigatorModel {
    // Linking
    var isLinked = DeviceKey.load() != nil
    var linkCode = ""
    var linkMessage: String?

    // Folders Navigator may look in (Roger picks them; nothing else is ever searched).
    var folders: [URL] = NavigatorModel.loadFolders()

    // Work
    var isPaused = UserDefaults.standard.bool(forKey: "nav.paused")
    var isWorking = false
    var now: String?
    var recent: [DoneTask] = []
    var problem: String?
    private var stopRequested = false
    private var loop: Task<Void, Never>?

    init() {
        startLoop()
    }

    // MARK: Linking

    func link() async {
        let code = linkCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        linkMessage = "Linking\u{2026}"
        do {
            let reply = try await Brain.send(["action": "pair", "code": code, "name": Host.current().localizedName ?? "Mac"])
            guard let key = reply["device_key"] as? String else { throw Brain.Failure(message: "That didn't work. Please try again.") }
            DeviceKey.save(key)
            isLinked = true
            linkCode = ""
            linkMessage = nil
            LocalRecord.write("linked", task: nil)
            startLoop()
        } catch {
            linkMessage = error.localizedDescription
        }
    }

    func unlink() {
        DeviceKey.delete()
        isLinked = false
        LocalRecord.write("unlinked_on_mac", task: nil)
    }

    // MARK: Folders

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.title = "Choose folders Navigator may look in"
        panel.prompt = "Allow"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !folders.contains(url) && !Searcher.isProtected(url.appendingPathComponent("x")) {
            folders.append(url)
        }
        saveFolders()
        LocalRecord.write("folders_changed", task: nil, detail: ["folders": folders.map(\.lastPathComponent)])
    }

    func remove(_ folder: URL) {
        folders.removeAll { $0 == folder }
        saveFolders()
        LocalRecord.write("folders_changed", task: nil, detail: ["folders": folders.map(\.lastPathComponent)])
    }

    private func saveFolders() {
        UserDefaults.standard.set(folders.map(\.path), forKey: "nav.folders")
    }

    private static func loadFolders() -> [URL] {
        (UserDefaults.standard.stringArray(forKey: "nav.folders") ?? []).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    // MARK: Pause and Stop

    func togglePause() {
        isPaused.toggle()
        UserDefaults.standard.set(isPaused, forKey: "nav.paused")
        LocalRecord.write(isPaused ? "paused" : "resumed", task: nil)
    }

    func stopNow() {
        stopRequested = true
        now = "Stopping\u{2026}"
    }

    // MARK: The work loop: ask for the next task every few seconds

    private func startLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isLinked && !self.isPaused && !self.folders.isEmpty && !self.isWorking {
                    await self.checkForWork()
                }
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func checkForWork() async {
        guard let key = DeviceKey.load() else { isLinked = false; return }
        do {
            let reply = try await Brain.send(["action": "next", "device_key": key])
            problem = nil
            guard let task = reply["task"] as? [String: Any],
                  let id = task["id"] as? String,
                  let request = task["request"] as? String else { return }
            let plan = task["plan"] as? [String: Any] ?? [:]
            await run(id: id, request: request, plan: plan, key: key)
        } catch {
            problem = error.localizedDescription
            if error.localizedDescription.contains("isn't linked") { DeviceKey.delete(); isLinked = false }
        }
    }

    private func run(id: String, request: String, plan: [String: Any], key: String) async {
        isWorking = true
        stopRequested = false
        defer { isWorking = false; now = nil }
        let words = plan["words"] as? [String] ?? []
        let kinds = plan["kinds"] as? [String] ?? ["any"]
        let days = plan["modified_within_days"] as? Int
        let say = plan["say"] as? String ?? "Searching your folders."
        now = say
        LocalRecord.write("picked_up", task: id, detail: ["request": request, "words": words, "kinds": kinds])

        let names = folders.map(\.lastPathComponent)
        let reply = try? await Brain.send(["action": "event", "device_key": key, "task_id": id,
                                           "kind": "searching", "detail": ["folders": names, "words": words]])
        if stopRequested || (reply?["stopped"] as? Bool) == true {
            LocalRecord.write("stopped", task: id)
            return
        }

        // The search runs off the main thread; it only reads Spotlight's index.
        let chosen = folders
        let outcome = await Task.detached(priority: .userInitiated) {
            Searcher.find(words: words, kinds: kinds, withinDays: days, in: chosen)
        }.value

        if stopRequested {
            LocalRecord.write("stopped", task: id)
            _ = try? await Brain.send(["action": "event", "device_key": key, "task_id": id, "kind": "stopped_on_mac", "detail": [String: Any]()])
            return
        }

        let iso = ISO8601DateFormatter()
        let files: [[String: Any]] = outcome.files.map {
            ["name": $0.url.lastPathComponent, "folder": $0.folderLabel, "modified": iso.string(from: $0.modified),
             "size": $0.size, "kind": $0.kind]
        }
        do {
            _ = try await Brain.send(["action": "result", "device_key": key, "task_id": id,
                                      "result": ["files": files, "searched": names, "skipped": outcome.skipped]])
            LocalRecord.write("done", task: id, detail: ["found": files.count, "skipped_protected": outcome.skipped, "changed": 0])
            recent.insert(DoneTask(id: id, request: request, say: say, files: outcome.files, when: Date()), at: 0)
        } catch {
            LocalRecord.write("send_failed", task: id, detail: ["error": error.localizedDescription])
            recent.insert(DoneTask(id: id, request: request, say: say, files: outcome.files, when: Date(),
                                   failed: "Found them, but couldn't send the list to your iPhone."), at: 0)
        }
        if recent.count > 8 { recent.removeLast(recent.count - 8) }
    }

    // MARK: Showing things

    func reveal(_ file: FoundFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
        LocalRecord.write("revealed_in_finder", task: nil, detail: ["name": file.url.lastPathComponent])
    }

    func openRecord() {
        NSWorkspace.shared.activateFileViewerSelecting([LocalRecord.file])
    }
}
