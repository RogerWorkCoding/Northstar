import Foundation
import AppKit
import Observation
import PDFKit

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

    /// Where most people's files live. Chosen from the start (Roger, Oct 19: people won't pick folders one
    /// by one). macOS asks "Allow?" once for each the first time Navigator looks there. Remove any in the menu.
    static let startingFolders: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Desktop", "Documents", "Downloads"].map { home.appendingPathComponent($0, isDirectory: true) }
    }()

    private static func loadFolders() -> [URL] {
        let d = UserDefaults.standard
        var saved = (d.stringArray(forKey: "nav.folders") ?? []).map { URL(fileURLWithPath: $0, isDirectory: true) }
        // Once: add the starting folders (kept if someone removes one later).
        if !d.bool(forKey: "nav.startingFoldersAdded") {
            for url in startingFolders where !saved.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) {
                saved.append(url)
            }
            d.set(true, forKey: "nav.startingFoldersAdded")
            d.set(saved.map(\.path), forKey: "nav.folders")
        }
        return saved
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
            if (task["stage"] as? String) == "continue" {
                await finish(id: id, request: request, plan: plan, choice: task["choice"] as? [String: Any] ?? [:], key: key)
            } else {
                await run(id: id, request: request, plan: plan, key: key)
            }
        } catch {
            problem = error.localizedDescription
            if error.localizedDescription.contains("isn't linked") { DeviceKey.delete(); isLinked = false }
        }
    }

    /// Stage 1: search. Level 1 (find) ends here. Levels 2-3 (read, email) send the best matches and
    /// wait for the person's OK on the iPhone: nothing is read or drafted before that.
    private func run(id: String, request: String, plan: [String: Any], key: String) async {
        isWorking = true
        stopRequested = false
        defer { isWorking = false; now = nil }
        let intent = plan["intent"] as? String ?? "find"
        let words = plan["words"] as? [String] ?? []
        let kinds = plan["kinds"] as? [String] ?? ["any"]
        let days = plan["modified_within_days"] as? Int
        let say = plan["say"] as? String ?? "Searching your folders."
        let email = plan["email"] as? [String: Any]
        let needsFiles = intent != "email" || (email?["attach"] as? Bool) == true
        now = say
        LocalRecord.write("picked_up", task: id, detail: ["request": request, "intent": intent, "words": words, "kinds": kinds])

        var outcome: (files: [FoundFile], skipped: Int) = ([], 0)
        let names = folders.map(\.lastPathComponent)
        if needsFiles && !words.isEmpty {
            let reply = try? await Brain.send(["action": "event", "device_key": key, "task_id": id,
                                               "kind": "searching", "detail": ["folders": names, "words": words]])
            if stopRequested || (reply?["stopped"] as? Bool) == true {
                LocalRecord.write("stopped", task: id)
                return
            }
            // The search runs off the main thread; it only reads Spotlight's index.
            let chosen = folders
            outcome = await Task.detached(priority: .userInitiated) {
                Searcher.find(words: words, kinds: kinds, withinDays: days, in: chosen)
            }.value
        }

        if stopRequested {
            LocalRecord.write("stopped", task: id)
            _ = try? await Brain.send(["action": "event", "device_key": key, "task_id": id, "kind": "stopped_on_mac", "detail": [String: Any]()])
            return
        }

        // Read and email offer only the best few, and remember exactly which files they were.
        let isCandidates = intent == "read" || intent == "email"
        let shown = isCandidates ? Array(outcome.files.prefix(5)) : outcome.files
        // Remember exactly which files were listed, so "Open #2" (or "read #2") is the file the person saw.
        Candidates.save(shown.map(\.url), for: id)

        let iso = ISO8601DateFormatter()
        let files: [[String: Any]] = shown.map {
            ["name": $0.url.lastPathComponent, "folder": $0.folderLabel, "modified": iso.string(from: $0.modified),
             "size": $0.size, "kind": $0.kind]
        }
        var body: [String: Any] = ["action": "result", "device_key": key, "task_id": id,
                                   "result": ["files": files, "searched": names, "skipped": outcome.skipped]]
        if isCandidates { body["stage"] = "candidates" }
        do {
            _ = try await Brain.send(body)
            LocalRecord.write(isCandidates ? "found_waiting_for_ok" : "done", task: id,
                              detail: ["found": files.count, "skipped_protected": outcome.skipped, "changed": 0])
            recent.insert(DoneTask(id: id, request: request,
                                   say: isCandidates ? "Waiting for your OK on your iPhone." : say,
                                   files: shown, when: Date()), at: 0)
        } catch {
            LocalRecord.write("send_failed", task: id, detail: ["error": error.localizedDescription])
            recent.insert(DoneTask(id: id, request: request, say: say, files: shown, when: Date(),
                                   failed: "Found them, but couldn't send the list to your iPhone."), at: 0)
        }
        if recent.count > 8 { recent.removeLast(recent.count - 8) }
    }

    /// Stage 2, only after the person's OK: read the one file they picked (Level 2), or open the email
    /// draft in Mail with the file they picked (Level 3). Mail never sends by itself: they press Send.
    private func finish(id: String, request: String, plan: [String: Any], choice: [String: Any], key: String) async {
        isWorking = true
        stopRequested = false
        defer { isWorking = false; now = nil }
        let intent = plan["intent"] as? String ?? "find"
        if intent == "open" {
            await openFound(id: id, request: request, choice: choice, key: key)
            return
        }
        let saved = Candidates.load(for: id)
        let index = choice["index"] as? Int
        let file: URL? = index.flatMap { $0 >= 0 && $0 < saved.count ? saved[$0] : nil }

        if intent == "read" {
            guard let file else {
                _ = try? await Brain.send(["action": "result", "device_key": key, "task_id": id,
                                           "error": "This Mac lost track of that file. Please ask again."])
                return
            }
            now = "Reading \(file.lastPathComponent)"
            LocalRecord.write("reading", task: id, detail: ["file": file.lastPathComponent, "you_approved": true])
            let text = await Task.detached(priority: .userInitiated) { TextReader.text(of: file) }.value
            if stopRequested { LocalRecord.write("stopped", task: id); return }
            do {
                _ = try await Brain.send(["action": "read_text", "device_key": key, "task_id": id,
                                          "name": file.lastPathComponent, "text": text])
                LocalRecord.write("answered", task: id, detail: ["file": file.lastPathComponent, "characters_sent": text.count])
                recent.insert(DoneTask(id: id, request: request, say: "Read \(file.lastPathComponent). The answer is on your iPhone.",
                                       files: [], when: Date()), at: 0)
            } catch {
                LocalRecord.write("send_failed", task: id, detail: ["error": error.localizedDescription])
            }
        } else if intent == "email" {
            let email = plan["email"] as? [String: Any] ?? [:]
            let to = (email["to"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let subject = email["subject"] as? String ?? ""
            let bodyText = email["body"] as? String ?? ""
            now = "Opening your draft in Mail"
            var items: [Any] = [bodyText]
            if let file { items.append(file) }
            let service = NSSharingService(named: .composeEmail)
            if to.contains("@") { service?.recipients = [to] }
            service?.subject = subject
            NSApp.activate(ignoringOtherApps: true)
            if let service, service.canPerform(withItems: items) {
                service.perform(withItems: items)
                LocalRecord.write("draft_opened", task: id, detail: ["app": "Mail", "attached": file?.lastPathComponent ?? "", "sent": false])
                _ = try? await Brain.send(["action": "draft_opened", "device_key": key, "task_id": id])
                recent.insert(DoneTask(id: id, request: request, say: "Draft is open in Mail. Check it and press Send.",
                                       files: [], when: Date()), at: 0)
            } else {
                _ = try? await Brain.send(["action": "result", "device_key": key, "task_id": id,
                                           "error": "Mail isn't set up on this Mac, so the draft couldn't open."])
            }
        }
        Candidates.clear(for: id)
        if recent.count > 8 { recent.removeLast(recent.count - 8) }
    }

    /// The person tapped Open or Show in Finder on a file Navigator found. Opens nothing else.
    private func openFound(id: String, request: String, choice: [String: Any], key: String) async {
        let source = choice["source"] as? String ?? ""
        let index = choice["index"] as? Int ?? -1
        let reveal = (choice["how"] as? String) == "reveal"
        let files = Candidates.load(for: source)
        guard index >= 0, index < files.count, FileManager.default.fileExists(atPath: files[index].path) else {
            _ = try? await Brain.send(["action": "result", "device_key": key, "task_id": id,
                                       "error": "That file has moved or this Mac lost track of it. Ask again to find it."])
            return
        }
        let url = files[index]
        if reveal {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url)
        }
        LocalRecord.write(reveal ? "revealed_in_finder" : "opened", task: id, detail: ["file": url.lastPathComponent, "you_asked": true])
        _ = try? await Brain.send(["action": "opened", "device_key": key, "task_id": id])
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


/// The files offered for an OK, remembered by task, so "read #2" means exactly the file the person saw.
enum Candidates {
    private static let key = "nav.candidates"

    static func save(_ urls: [URL], for task: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        all[task] = urls.map(\.path)
        if all.count > 20 { all = Dictionary(uniqueKeysWithValues: all.suffix(20).map { ($0.key, $0.value) }) }
        UserDefaults.standard.set(all, forKey: key)
    }

    static func load(for task: String) -> [URL] {
        let all = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        return (all[task] ?? []).map { URL(fileURLWithPath: $0) }
    }

    static func clear(for task: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        all[task] = nil
        UserDefaults.standard.set(all, forKey: key)
    }
}

/// Level 2: the text of one file, read on this Mac (PDF, Word, RTF, plain text). At most 60,000 characters.
enum TextReader {
    static func text(of url: URL) -> String {
        let limit = 60_000
        let ext = url.pathExtension.lowercased()
        var out = ""
        if ext == "pdf", let doc = PDFDocument(url: url) {
            out = doc.string ?? ""
        } else if ["docx", "doc", "rtf", "rtfd", "html", "htm", "odt"].contains(ext),
                  let a = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            out = a.string
        } else if let s = try? String(contentsOf: url, encoding: .utf8) {
            out = s
        }
        return String(out.prefix(limit))
    }
}
