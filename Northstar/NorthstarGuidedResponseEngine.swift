import Foundation

struct NorthstarGuidedResponseEngine {

    static func response(
        for prompt: String,
        disciplines: [NorthstarDiscipline]
    ) -> String {

        let text = prompt.lowercased()

        if disciplines.contains(.appDevelopment) {
            if text.contains("swiftui") ||
               text.contains("xcode") {
                return """
                I can help you build this step by step.

                Where should we begin?

                • Plan the feature
                • Design the screen
                • Write the code
                • Fix a problem
                """
            }

            return """
            Let's define the app before building it.

            What would you like help with first?

            • App concept
            • Screen design
            • SwiftUI development
            • Xcode troubleshooting
            """
        }

        if disciplines.contains(.webDevelopment) {
            return """
            Let's establish the website's direction first.

            What do you want to work on?

            • Page structure
            • Visual design
            • Content
            • HTML and CSS
            """
        }

        if disciplines.contains(.branding) {
            return """
            Let's clarify the brand direction.

            What would you like to develop?

            • Brand identity
            • Logo concept
            • Color and typography
            • Marketing message
            """
        }

        if disciplines.contains(.aiExperience) {
            return """
            Let's define how the intelligent experience should help the user.

            Where should we begin?

            • AI behavior
            • Conversation flow
            • Intent routing
            • User trust
            """
        }

        if disciplines.contains(.systemsArchitecture) {
            return """
            Let's understand how the system needs to work.

            What should we focus on first?

            • Architecture
            • Integrations
            • Data flow
            • Scalability
            """
        }

        return """
        I'd be happy to help.

        What would you like to focus on?

        • Explore the idea
        • Improve the design
        • Define the direction
        • Decide the next step
        """
    }
}
