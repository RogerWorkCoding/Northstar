import Foundation

struct NorthstarIntelligence {

    func detectIntent(
        from prompt: String
    ) -> NorthstarIntent {

        let text = prompt.lowercased()

        // Engine first: everything goes to Northstar's brain, which decides
        // how to help (guidance, wireframes, honest "I can't do that yet").
        // Only clear, explicit commands for app features are caught here.

        // PDF (explicit command only)
        let pdfCommands = ["create pdf", "make pdf", "make a pdf", "create a pdf",
                           "generate pdf", "save pdf", "save as pdf", "export pdf"]
        if pdfCommands.contains(where: { text.contains($0) }) {
            return .documentCreation
        }

        // Look at a photo (explicit command only)
        let analysisCommands = ["analyze image", "analyze photo", "analyze picture",
                                "look at this photo", "look at this picture"]
        if analysisCommands.contains(where: { text.contains($0) }) {
            return .imageAnalysis
        }

        return .conversation
    }
}
