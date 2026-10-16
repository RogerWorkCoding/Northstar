import SwiftUI
import UIKit
import UniformTypeIdentifiers

// 📄 Copy or share a whole conversation.
// Plain text for pasting anywhere; a Word-friendly document (.rtf) for sharing,
// with "You" and "Northstar" in bold so it reads cleanly in Word or Pages.

/// One line of the chat, ready to export (plain values, safe to use off the main thread).
nonisolated struct ChatLine: Sendable, Hashable {
    let fromYou: Bool
    let text: String
}

nonisolated enum ChatExport {
    @MainActor static func lines(_ messages: [MessageModel]) -> [ChatLine] {
        messages.compactMap { m in
            let t = m.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : ChatLine(fromYou: m.role == .user, text: t)
        }
    }

    /// "Northstar chat · Friday, October 16, 2026"
    static func heading() -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        return "Northstar chat · " + f.string(from: Date())
    }

    static func plainText(_ lines: [ChatLine]) -> String {
        ([heading()] + lines.map { ($0.fromYou ? "You" : "Northstar") + ":\n" + $0.text })
            .joined(separator: "\n\n")
    }

    static func rtf(_ lines: [ChatLine]) throws -> Data {
        let out = NSMutableAttributedString(string: heading() + "\n\n",
                                            attributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
        for line in lines {
            out.append(NSAttributedString(string: (line.fromYou ? "You" : "Northstar") + "\n",
                                          attributes: [.font: UIFont.boldSystemFont(ofSize: 13)]))
            out.append(NSAttributedString(string: line.text + "\n\n",
                                          attributes: [.font: UIFont.systemFont(ofSize: 13)]))
        }
        return try out.data(from: NSRange(location: 0, length: out.length),
                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
}

/// The conversation as a file that opens in Word (made only when they actually share).
nonisolated struct ChatDocument: Transferable {
    let lines: [ChatLine]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .rtf) { doc in
            let data = try ChatExport.rtf(doc.lines)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Northstar chat \(f.string(from: Date())).rtf")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
