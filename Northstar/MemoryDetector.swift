import Foundation

struct MemoryDetector {

    func detectCandidate(
        from message: String
    ) -> MemoryCandidate? {

        let cleanedMessage =
            message.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard cleanedMessage.count >= 12 else {
            return nil
        }

        let normalized =
            cleanedMessage.lowercased()

        if containsExplicitMemoryRequest(
            normalized
        ) {
            return MemoryCandidate(
                content: cleanedMessage,
                suggestedSubject:
                    suggestedSubject(
                        for: normalized
                    ),
                reason:
                    "You explicitly asked Northstar to remember this."
            )
        }

        if containsDecisionLanguage(
            normalized
        ) {
            return MemoryCandidate(
                content: cleanedMessage,
                suggestedSubject:
                    suggestedSubject(
                        for: normalized
                    ),
                reason:
                    "This appears to express an ongoing decision."
            )
        }

        if containsPreferenceLanguage(
            normalized
        ) {
            return MemoryCandidate(
                content: cleanedMessage,
                suggestedSubject:
                    suggestedSubject(
                        for: normalized
                    ),
                reason:
                    "This appears to describe an ongoing preference."
            )
        }

        if containsProjectDirection(
            normalized
        ) {
            return MemoryCandidate(
                content: cleanedMessage,
                suggestedSubject:
                    suggestedSubject(
                        for: normalized
                    ),
                reason:
                    "This appears to define an ongoing project direction."
            )
        }

        return nil
    }

    private func containsExplicitMemoryRequest(
        _ text: String
    ) -> Bool {

        let phrases = [
            "remember this",
            "remember that",
            "save this",
            "save this decision",
            "keep this for later",
            "don't forget",
            "do not forget",
            "put this in memory"
        ]

        return phrases.contains {
            text.contains($0)
        }
    }

    private func containsDecisionLanguage(
        _ text: String
    ) -> Bool {

        let phrases = [
            "we decided",
            "i decided",
            "the decision is",
            "we are going to",
            "we will use",
            "we should use",
            "the direction is",
            "the final direction",
            "from now on"
        ]

        return phrases.contains {
            text.contains($0)
        }
    }

    private func containsPreferenceLanguage(
        _ text: String
    ) -> Bool {

        let phrases = [
            "i prefer",
            "i want northstar to",
            "i don't want",
            "i do not want",
            "always use",
            "never use",
            "my preference is"
        ]

        return phrases.contains {
            text.contains($0)
        }
    }

    private func containsProjectDirection(
        _ text: String
    ) -> Bool {

        let phrases = [
            "northstar should",
            "northstar will",
            "the app should",
            "the product should",
            "the memory system should",
            "the architecture should",
            "our next step is",
            "the foundation will"
        ]

        return phrases.contains {
            text.contains($0)
        }
    }

    private func suggestedSubject(
        for text: String
    ) -> String {

        if text.contains("memory") {
            return "Memory"
        }

        if text.contains("document")
            || text.contains("pdf") {
            return "Documents"
        }

        if text.contains("website")
            || text.contains("web design") {
            return "Website"
        }

        if text.contains("brand")
            || text.contains("icon")
            || text.contains("logo") {
            return "Brand Identity"
        }

        if text.contains("architecture")
            || text.contains("database")
            || text.contains("supabase") {
            return "Architecture"
        }

        if text.contains("reflection")
            || text.contains("clarity") {
            return "Reflection"
        }

        if text.contains("northstar") {
            return "Northstar Labs"
        }

        return "General"
    }
}
