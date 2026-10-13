import Foundation

struct NorthstarIntelligence {

    func detectIntent(
        from prompt: String
    ) -> NorthstarIntent {

        let text = prompt.lowercased()

        // PDF + Documents

        if text.contains("pdf") ||
           text.contains("document") ||
           text.contains("create document") ||
           text.contains("make document") ||
           text.contains("generate document") ||
           text.contains("create pdf") ||
           text.contains("make pdf") ||
           text.contains("generate pdf") ||
           text.contains("save pdf") ||
           text.contains("brief") {

            return .documentCreation
        }

        // Images

        if text.contains("create image") ||
           text.contains("generate image") ||
           text.contains("logo") ||
           text.contains("illustration") {

            return .imageGeneration
        }

        // Video

        if text.contains("video") {

            return .videoGeneration
        }

        // Website

        if text.contains("website") ||
           text.contains("web design") ||
           text.contains("landing page") ||
           text.contains("web page") {

            return .webDesign
        }

        // Image Analysis

        if text.contains("photo") ||
           text.contains("picture") ||
           text.contains("analyze image") {

            return .imageAnalysis
        }

        // Projects

        if text.contains("project") {

            return .projectGuidance
        }

        return .conversation
    }
}
