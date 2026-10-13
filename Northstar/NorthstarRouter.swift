import Foundation

struct NorthstarRouter {

    static func responseStyle(
        for disciplines: [NorthstarDiscipline]
    ) -> NorthstarResponseStyle {

        if disciplines.contains(.appDevelopment) {
            return .appDevelopment
        }

        if disciplines.contains(.webDevelopment) {
            return .webDevelopment
        }

        if disciplines.contains(.branding) {
            return .branding
        }

        return .design
    }
    
    static func disciplinesForPrompt(
        _ prompt: String
    ) -> [NorthstarDiscipline] {

        let text = prompt.lowercased()

        if text.contains("swift") ||
           text.contains("swiftui") ||
           text.contains("xcode") ||
           text.contains("ios") ||
           text.contains("iphone") ||
           text.contains("ipad") {

            return [
                .appDevelopment
            ]
        }

        if text.contains("website") ||
           text.contains("web") {

            return [
                .webDevelopment,
                .branding
            ]
        }

        if text.contains("logo") ||
           text.contains("brand") {

            return [
                .branding,
                .design
            ]
        }

        return [
            .design
        ]
    }
}
