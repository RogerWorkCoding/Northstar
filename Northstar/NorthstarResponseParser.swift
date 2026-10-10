import Foundation

// Compatibility layer only: converts the current plain-String message pipeline into
// NorthstarStructuredResponse by inferring hierarchy from Markdown-ish conventions
// (##, -, **bold**). Once the backend returns structured JSON directly, callers should
// decode into NorthstarStructuredResponse and skip this parser entirely.
enum NorthstarResponseParser {

    static func parse(_ rawText: String) -> NorthstarStructuredResponse {
        let trimmedInput = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return NorthstarStructuredResponse() }

        let (labels, remainder) = extractLabels(from: trimmedInput)
        let lines = remainder.components(separatedBy: "\n")

        var directAnswer: String?
        var title: String?
        var introduction: String?
        var sections: [NorthstarResponseSection] = []
        var recommendedAction: NorthstarResponseItem?

        var currentHeading: String?
        var currentBodyLines: [String] = []
        var currentItems: [NorthstarResponseItem] = []
        var isRecommendationSection = false
        var sawAnyHeading = false

        func flushCurrentSection() {
            defer {
                currentHeading = nil
                currentBodyLines = []
                currentItems = []
                isRecommendationSection = false
            }
            guard currentHeading != nil || !currentBodyLines.isEmpty || !currentItems.isEmpty else { return }
            let body = currentBodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            if isRecommendationSection {
                if currentItems.count == 1, body.isEmpty {
                    recommendedAction = currentItems.first
                } else {
                    let combined = ([body] + currentItems.map(\.detail))
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    guard !combined.isEmpty else { return }
                    recommendedAction = NorthstarResponseItem(lead: nil, detail: combined)
                }
                return
            }

            sections.append(
                NorthstarResponseSection(
                    heading: currentHeading,
                    body: body.isEmpty ? nil : body,
                    items: currentItems
                )
            )
        }

        for line in lines {
            if let heading = headingContent(of: line) {
                flushCurrentSection()
                sawAnyHeading = true
                let lowerHeading = heading.lowercased()
                if lowerHeading.contains("recommended action") || lowerHeading.contains("next step") {
                    isRecommendationSection = true
                    currentHeading = heading
                } else if title == nil && sections.isEmpty {
                    title = heading
                } else {
                    currentHeading = heading
                }
                continue
            }

            if let bulletText = bulletContent(of: line) {
                let (lead, detail) = splitLeadDetail(bulletText)
                guard !detail.isEmpty else { continue }
                currentItems.append(NorthstarResponseItem(lead: lead, detail: detail))
                continue
            }

            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            let cleaned = stripBold(trimmedLine)

            if currentHeading == nil, sections.isEmpty, !sawAnyHeading, directAnswer == nil, currentItems.isEmpty {
                directAnswer = cleaned
            } else if currentHeading == nil, sections.isEmpty, introduction == nil {
                introduction = cleaned
            } else {
                currentBodyLines.append(cleaned)
            }
        }

        flushCurrentSection()

        return NorthstarStructuredResponse(
            directAnswer: directAnswer,
            title: title,
            labels: labels,
            introduction: introduction,
            sections: sections,
            recommendedAction: recommendedAction
        )
    }

    // MARK: - Labels

    /// Recognizes an optional leading "Labels: A, B" line or a leading "[A] [B]" line.
    /// A bracketed line only counts when it sits at the very start and every token is short
    /// and unnested — anything else (ordinary prose that happens to contain brackets) is left
    /// untouched so it isn't mistaken for a label row.
    private static func extractLabels(from text: String) -> (labels: [String], remainder: String) {
        var lines = text.components(separatedBy: "\n")
        guard let firstLine = lines.first else { return ([], text) }
        let trimmedFirst = firstLine.trimmingCharacters(in: .whitespaces)

        if trimmedFirst.lowercased().hasPrefix("labels:") {
            let afterColon = trimmedFirst.dropFirst("labels:".count)
            let candidates = afterColon.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count <= 24 }
            if !candidates.isEmpty {
                lines.removeFirst()
                return (Array(candidates.prefix(6)), lines.joined(separator: "\n"))
            }
        }

        if let bracketLabels = parseBracketLabelsLine(trimmedFirst) {
            lines.removeFirst()
            return (bracketLabels, lines.joined(separator: "\n"))
        }

        return ([], text)
    }

    /// Returns labels only if the entire line is a run of short, unnested "[Label]" tokens.
    private static func parseBracketLabelsLine(_ line: String) -> [String]? {
        guard line.hasPrefix("[") else { return nil }
        var labels: [String] = []
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == " " {
                index = line.index(after: index)
                continue
            }
            guard line[index] == "[" else { return nil }
            guard let closeIndex = line[index...].firstIndex(of: "]") else { return nil }
            let innerStart = line.index(after: index)
            let inner = line[innerStart..<closeIndex].trimmingCharacters(in: .whitespaces)
            guard !inner.isEmpty, inner.count <= 24, !inner.contains("[") else { return nil }
            labels.append(inner)
            if labels.count > 6 { return nil }
            index = line.index(after: closeIndex)
        }
        return labels.isEmpty ? nil : labels
    }

    // MARK: - Line classification

    private static func headingContent(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        var index = trimmed.startIndex
        while index < trimmed.endIndex, trimmed[index] == "#" {
            index = trimmed.index(after: index)
        }
        guard index < trimmed.endIndex, trimmed[index] == " " else { return nil }
        let text = trimmed[trimmed.index(after: index)...].trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func bulletContent(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "* ", "• "] {
            if trimmed.hasPrefix(marker) {
                return String(trimmed.dropFirst(marker.count))
            }
        }
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = trimmed[trimmed.startIndex..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return nil }
        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex, trimmed[afterDot] == " " else { return nil }
        return String(trimmed[trimmed.index(after: afterDot)...])
    }

    /// Splits "**Lead** detail" into (lead, detail). Falls back to (nil, plain text) for
    /// anything else, including unmatched/malformed "**" markers.
    private static func splitLeadDetail(_ text: String) -> (lead: String?, detail: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("**") else { return (nil, stripBold(trimmed)) }

        let afterOpen = trimmed.index(trimmed.startIndex, offsetBy: 2)
        guard afterOpen < trimmed.endIndex,
              let closeRange = trimmed.range(of: "**", range: afterOpen..<trimmed.endIndex) else {
            return (nil, stripBold(trimmed))
        }

        let lead = trimmed[afterOpen..<closeRange.lowerBound].trimmingCharacters(in: .whitespaces)
        guard !lead.isEmpty else { return (nil, stripBold(trimmed)) }

        var rest = trimmed[closeRange.upperBound...].trimmingCharacters(in: .whitespaces)
        for connector in ["—", "-", ":"] where rest.hasPrefix(connector) {
            rest = String(rest.dropFirst(connector.count)).trimmingCharacters(in: .whitespaces)
            break
        }

        return (lead, stripBold(rest))
    }

    private static func stripBold(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
    }
}
