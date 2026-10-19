import Foundation
import UIKit

// 📓 Good Listener: the private journal. Everything lives on this phone only (Application Support, locked
// while the phone is locked, left out of iCloud backup). Nothing here goes to the brain, memory or the
// server unless the person taps "Talk this through" or shares notes themselves.

nonisolated struct JournalAttachment: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case image, pdf }
    var id = UUID()
    var kind: Kind
    var fileName: String     // the file in the journal folder
    var name: String         // what the person sees ("Photo", "Letter.pdf")
}

nonisolated struct JournalItem: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var text: String
    var created = Date()
    var updated = Date()
    var attachments: [JournalAttachment] = []
}

@MainActor @Observable
final class JournalStore {
    static let shared = JournalStore()

    private(set) var entries: [JournalItem] = []
    /// Shown when the journal couldn't be read or saved (never silently lost).
    var problem: String?

    private let folder: URL
    private var listFile: URL { folder.appendingPathComponent("entries.json") }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        folder = base.appendingPathComponent("Journal", isDirectory: true)
        prepareFolder()
        load()
    }

    private func prepareFolder() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.complete])
            var url = folder
            var values = URLResourceValues()
            values.isExcludedFromBackup = true     // stays on this phone
            try url.setResourceValues(values)
        } catch {
            problem = "Your journal folder couldn't be set up."
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: listFile) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([JournalItem].self, from: data).sorted { $0.created > $1.created }
        } catch {
            problem = "Your journal couldn't be read."
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(entries).write(to: listFile, options: [.atomic, .completeFileProtection])
            problem = nil
        } catch {
            problem = "Your journal couldn't be saved. Please try again."
        }
    }

    // MARK: Entries

    @discardableResult
    func add(title: String, text: String, attachments: [JournalAttachment] = []) -> JournalItem {
        let item = JournalItem(title: Self.cleanTitle(title), text: text, attachments: attachments)
        entries.insert(item, at: 0)
        persist()
        return item
    }

    func update(_ item: JournalItem) {
        guard let i = entries.firstIndex(where: { $0.id == item.id }) else { return }
        var changed = item
        changed.title = Self.cleanTitle(item.title)
        changed.updated = .now
        // Files of attachments that were removed are deleted too.
        let kept = Set(changed.attachments.map(\.fileName))
        for old in entries[i].attachments where !kept.contains(old.fileName) { removeFile(old.fileName) }
        entries[i] = changed
        persist()
    }

    func delete(_ item: JournalItem) {
        for a in item.attachments { removeFile(a.fileName) }
        entries.removeAll { $0.id == item.id }
        persist()
    }

    func entry(_ id: UUID) -> JournalItem? { entries.first { $0.id == id } }

    // MARK: Attachments (photos and PDFs about themselves)

    func saveAttachment(_ data: Data, kind: JournalAttachment.Kind, name: String) -> JournalAttachment? {
        let fileName = UUID().uuidString + (kind == .pdf ? ".pdf" : ".jpg")
        do {
            try data.write(to: folder.appendingPathComponent(fileName), options: [.atomic, .completeFileProtection])
            return JournalAttachment(kind: kind, fileName: fileName, name: name)
        } catch {
            problem = "That file couldn't be added."
            return nil
        }
    }

    func url(for attachment: JournalAttachment) -> URL {
        folder.appendingPathComponent(attachment.fileName)
    }

    func data(for attachment: JournalAttachment) -> Data? {
        try? Data(contentsOf: url(for: attachment))
    }

    /// Files added but never saved in an entry (the person cancelled).
    func discard(_ attachments: [JournalAttachment]) {
        for a in attachments { removeFile(a.fileName) }
    }

    private func removeFile(_ fileName: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(fileName))
    }

    private static func cleanTitle(_ title: String) -> String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Journal entry" : String(t.prefix(80))
    }
}
