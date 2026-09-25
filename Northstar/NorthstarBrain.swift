import Foundation

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct NorthstarBrain {
    // This connects to Secrets.swift to grab your password behind the scenes
    let apiKey = OPENAI_API_KEY
    
    func getResponse(for prompt: String) async -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemMessage = "You are Northstar, an elite AI Graphic Design Director. You analyze layouts, typography, and color theory to elevate creative projects. Keep responses concise, professional, and tailored to a premium design agency aesthetic. The user's name is Roger. Their 21-year-old cat is named Phoebe."
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": prompt]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            if let text = decodedResponse.choices.first?.message.content {
                return text
            }
        } catch {
            print("Network error: \(error)")
        }
        
        return "I am currently experiencing a network interruption. Let's review the creative brief offline."
    }
}
