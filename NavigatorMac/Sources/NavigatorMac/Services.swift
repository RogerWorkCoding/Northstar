import Foundation
import Security
import CryptoKit

// MARK: - Talking to the Northstar brain (the northstar-navigator function)

enum Brain {
    static let url = URL(string: "https://ozvwmxgvlibaxkogjbpe.supabase.co/functions/v1/northstar-navigator")!
    /// The public app key (the same one the iPhone app and the website use). Not a secret.
    static let publicKey = "sb_publishable_5TLjbssyYV_kl6g9T7TudA_FCjZQFcf"

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func send(_ body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(publicKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(publicKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let reply = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status >= 400 {
            throw Failure(message: reply["error"] as? String ?? "Northstar couldn't be reached (\(status)).")
        }
        return reply
    }
}

// MARK: - The device key, kept in this Mac's Keychain

enum DeviceKey {
    private static let service = "com.mynorthstarlabs.navigator"
    private static let account = "device-key"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        delete()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(key.utf8),
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - This Mac's own record (written by code, never by the AI)

/// One line per event in ~/Library/Application Support/Northstar Navigator/record.jsonl.
/// Each line carries the fingerprint of the line before it, so a changed or missing line shows.
enum LocalRecord {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Northstar Navigator", isDirectory: true)
    }
    static var file: URL { folder.appendingPathComponent("record.jsonl") }

    static func write(_ kind: String, task: String?, detail: [String: Any] = [:]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let prev = lastHash()
        var entry: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "kind": kind,
            "detail": detail,
            "prev": prev.map { $0 as Any } ?? NSNull(),
        ]
        if let task { entry["task"] = task }
        let body = (try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])) ?? Data()
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        entry["hash"] = hash
        guard var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        if fm.fileExists(atPath: file.path), let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            fm.createFile(atPath: file.path, contents: line, attributes: [.posixPermissions: 0o600])
        }
    }

    private static func lastHash() -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let last = text.split(separator: "\n").last,
              let obj = try? JSONSerialization.jsonObject(with: Data(last.utf8)) as? [String: Any] else { return nil }
        return obj["hash"] as? String
    }
}

// MARK: - Searching (look only)

struct FoundFile: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let folderLabel: String      // e.g. "Documents › Insurance"
    let modified: Date
    let size: Int
    let kind: String
    let matches: Int             // how many search words it matched
}

enum Searcher {
    /// Places Navigator never looks, even inside a folder Roger picked.
    static let protectedParts = ["/.ssh", "/Library/Keychains", "/Keys/", "/.gnupg", "/.aws", "/Library/Application Support/Northstar Navigator"]
    static let protectedExtensions = ["mobileconfig", "keychain", "keychain-db", "pem", "p12", "key"]

    static let kindExtensions: [String: [String]] = [
        "pdf": ["pdf"],
        "document": ["doc", "docx", "pages", "rtf", "odt", "txt", "md"],
        "spreadsheet": ["xls", "xlsx", "numbers", "csv", "ods"],
        "presentation": ["ppt", "pptx", "key", "odp"],
        "image": ["jpg", "jpeg", "png", "heic", "gif", "webp", "tiff", "psd", "svg"],
        "video": ["mov", "mp4", "m4v", "avi"],
        "audio": ["mp3", "m4a", "wav", "aiff"],
        "text": ["txt", "md", "rtf"],
        "archive": ["zip", "dmg", "tar", "gz"],
    ]

    static func isProtected(_ url: URL) -> Bool {
        let path = url.path
        if protectedParts.contains(where: { path.contains($0) }) { return true }
        if url.pathComponents.contains(where: { $0.hasPrefix(".") }) { return true }
        if path.contains(".app/") { return true }
        return protectedExtensions.contains(url.pathExtension.lowercased())
    }

    static func kindName(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return kindExtensions.first(where: { $0.value.contains(ext) })?.key ?? (ext.isEmpty ? "file" : ext)
    }

    /// Runs Spotlight (mdfind) in each chosen folder. Returns the best matches and how many were skipped.
    static func find(words: [String], kinds: [String], withinDays: Int?, in folders: [URL]) -> (files: [FoundFile], skipped: Int) {
        let clean = words.map { $0.replacingOccurrences(of: "\"", with: "") }.filter { !$0.isEmpty }
        guard !clean.isEmpty else { return ([], 0) }
        let allowedExt: Set<String>? = kinds.contains("any") || kinds.isEmpty
            ? nil
            : Set(kinds.flatMap { kindExtensions[$0] ?? [] })
        let since = withinDays.map { Date().addingTimeInterval(-Double($0) * 86_400) }

        var score: [String: Int] = [:]
        var owner: [String: URL] = [:]
        for folder in folders {
            // Each word on its own, so a file matching more of the words ranks higher.
            for word in clean {
                for path in mdfind(word, in: folder) {
                    score[path, default: 0] += 1
                    owner[path] = folder
                }
            }
        }

        var skipped = 0
        var found: [FoundFile] = []
        for (path, matches) in score {
            let url = URL(fileURLWithPath: path)
            if isProtected(url) { skipped += 1; continue }
            if let allowedExt, !allowedExt.contains(url.pathExtension.lowercased()) { continue }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]),
                  values.isDirectory != true else { continue }
            let modified = values.contentModificationDate ?? .distantPast
            if let since, modified < since { continue }
            let root = owner[path] ?? url.deletingLastPathComponent()
            found.append(FoundFile(url: url, folderLabel: label(for: url, root: root), modified: modified,
                                   size: values.fileSize ?? 0, kind: kindName(url), matches: matches))
        }
        found.sort { ($0.matches, $0.modified) > ($1.matches, $1.modified) }
        return (Array(found.prefix(25)), skipped)
    }

    /// "Documents › Insurance" (the chosen folder's name, then the folders inside it).
    static func label(for url: URL, root: URL) -> String {
        let parent = url.deletingLastPathComponent().standardizedFileURL.pathComponents
        let base = root.standardizedFileURL.pathComponents
        let inside = parent.count > base.count ? Array(parent[base.count...]) : []
        return ([root.lastPathComponent] + inside).joined(separator: " › ")
    }

    private static func mdfind(_ word: String, in folder: URL) -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        task.arguments = ["-onlyin", folder.path, word]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).prefix(400).map { $0 }
    }
}
