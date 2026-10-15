import SwiftUI
import UIKit

// 💻 Code cards (Coding module): each piece of code Northstar writes gets its own card —
// a title, the language, the code in an easy-to-read monospace box that scrolls sideways,
// one plain line on what it does, and a Copy button. Code never sits inside the chat text.

struct CodeCardsView: View {
    let snippets: [NorthstarInsight.CodeSnippet]

    @State private var copied: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text("CODE").tracking(2)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            ForEach(Array(snippets.enumerated()), id: \.offset) { index, snippet in
                card(index: index, snippet: snippet)
            }
        }
    }

    private func card(index: Int, snippet: NorthstarInsight.CodeSnippet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(snippet.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.text)
                Spacer(minLength: 8)
                Text(Self.languageName(snippet.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.label)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
            }

            // The code itself: always light-on-dark like a code editor, in Day and Night.
            ScrollView(.horizontal, showsIndicators: true) {
                Text(snippet.code)
                    .font(.system(size: 14, design: .monospaced))
                    .lineSpacing(3)
                    .foregroundStyle(Color(red: 0.90, green: 0.92, blue: 0.96))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.06, green: 0.09, blue: 0.18)))
            .accessibilityLabel("\(Self.languageName(snippet.language)) code: \(snippet.title)")

            if !snippet.explain.isEmpty {
                Text(snippet.explain)
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                UIPasteboard.general.string = snippet.code
                withAnimation(.easeOut(duration: 0.2)) { copied = index }
            } label: {
                Label(copied == index ? "Copied" : "Copy code",
                      systemImage: copied == index ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(NorthstarChatStyle.primaryFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied == index ? "Copied \(snippet.title)" : "Copy code for \(snippet.title)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }

    /// "swiftui" → "SwiftUI", "powerfx" → "Power Fx"
    static func languageName(_ code: String) -> String {
        switch code {
        case "swift": return "Swift"
        case "swiftui": return "SwiftUI"
        case "javascript": return "JavaScript"
        case "typescript": return "TypeScript"
        case "html": return "HTML"
        case "css": return "CSS"
        case "sql": return "SQL"
        case "python": return "Python"
        case "json": return "JSON"
        case "powerfx": return "Power Fx"
        case "bash": return "Terminal"
        default: return "Text"
        }
    }
}
