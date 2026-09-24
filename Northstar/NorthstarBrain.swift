import Foundation

struct NorthstarBrain {
    func getResponse(for prompt: String) -> String {
        // Converts the prompt to lowercase so it catches "Hello" or "hello"
        let lowercasedPrompt = prompt.lowercased()
        
        // The Brain's logic rules
        if lowercasedPrompt.contains("hello") || lowercasedPrompt.contains("hi") {
            return "Hello, Roger. I am Northstar. How can I help you today?"
        } else if lowercasedPrompt.contains("who are you") {
            return "I am an AI interface built by you, designed to navigate your path forward."
        } else {
            return "I am currently running on my local logic center, so my responses are limited right now."
        }
    }
}
