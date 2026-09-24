import Foundation

struct NorthstarBrain {
    func getResponse(for prompt: String) -> String {
        let lowercasedPrompt = prompt.lowercased()
        
        // The Brain's new Creative Director logic rules
        if lowercasedPrompt.contains("hello") || lowercasedPrompt.contains("hi") {
            return "Hello, Roger. Northstar Creative Direction is online. What are we designing today?"
        } else if lowercasedPrompt.contains("who are you") {
            return "I am Northstar, your AI Graphic Design Director. I analyze layouts, typography, and color theory to elevate your creative projects."
        } else if lowercasedPrompt.contains("phoebe") {
            return "Ah, Phoebe. The true boss of the studio. I hope her 21-year-old royal highness is having a relaxing day."
        } else if lowercasedPrompt.contains("color") || lowercasedPrompt.contains("palette") {
            return "For a modern, premium brand, I recommend a high-contrast palette: deep slate backgrounds with vibrant cyan or stark white accents to control the viewer's focus."
        } else {
            return "I am ready to review your design brief. Please provide more details on the typography, layout, or brand identity you want to explore."
        }
    }
}
