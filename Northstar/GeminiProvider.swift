import Foundation

struct GeminiProvider {

    // Retired: Northstar now uses NorthstarEngineClient (Claude via Supabase).
    // No AI keys live in the app anymore.
    private let apiKey = ""
    private let model = "gemini-3.5-flash"

    func getResponse(
        for messages: [MessageModel]
    ) async -> String {

        let endpoint =
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"

        guard let url = URL(string: endpoint) else {
            return "I couldn't start the request."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        request.setValue(
            apiKey,
            forHTTPHeaderField: "x-goog-api-key"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        let systemPrompt = """
        You are Northstar, one unified intelligent guide.

        Help people move forward toward their goals.

        Do not behave like a search engine or encyclopedia.
        When a request is ambiguous, use the conversation context
        and choose the most practical interpretation.

        When responding:

        Do not define terms unless the user explicitly asks for a definition.

        Focus on the user's destination rather than explaining concepts.

        Always respond exactly in this format.

        IMPORTANT:

        Leave a completely blank line after every heading.

        Leave a completely blank line between every section.

        Example:

        ## Understanding

        You want to build an iPhone app.

        ## Recommended Direction

        • Define the app idea

        • Build the first screen

        • Test on your device

        ## Next Recommended Action

        Create a new SwiftUI project in Xcode.

        Avoid:
        - encyclopedic explanations
        - multiple interpretations
        - historical background
        - long definitions
        - listing unrelated possibilities

        Choose the most likely interpretation based on the user's intent.
        Give one specific action the user can take now.

        Keep responses concise, conversational, and easy to understand.
        Prefer useful guidance over excessive information.
        Ask a question only when essential information is missing.

        Never ask users to choose personas, expertise levels,
        intelligence tiers, or AI models.

        Northstar intelligently applies the relevant knowledge internally.

        One clear destination.
        An intelligent path forward.
        """

        let conversation: [[String: Any]] =
            messages.map { message in
                [
                    "role": message.role == .user
                        ? "user"
                        : "model",
                    "parts": [
                        [
                            "text": message.content
                        ]
                    ]
                ]
            }

        let requestBody: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    [
                        "text": systemPrompt
                    ]
                ]
            ],
            "contents": conversation,
            "generationConfig": [
                "temperature": 0.6,
                "maxOutputTokens": 1200
            ]
        ]

        do {
            request.httpBody =
                try JSONSerialization.data(
                    withJSONObject: requestBody
                )

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard let httpResponse =
                    response as? HTTPURLResponse else {
                return "I couldn't read the server response."
            }

            print(
                "Gemini status:",
                httpResponse.statusCode
            )

            guard (200...299).contains(
                httpResponse.statusCode
            ) else {
                if let errorText = String(
                    data: data,
                    encoding: .utf8
                ) {
                    print(
                        "Gemini API error:",
                        errorText
                    )
                }

                switch httpResponse.statusCode {
                case 429:
                    return """
                    Gemini has reached its current request limit. Please try again shortly.
                    """

                case 503:
                    return """
                    Gemini is currently busy. Please try again shortly.
                    """

                default:
                    return "I couldn't complete that request."
                }
            }

            guard
                let json =
                    try JSONSerialization.jsonObject(
                        with: data
                    ) as? [String: Any],
                let candidates =
                    json["candidates"] as? [[String: Any]],
                let candidate = candidates.first,
                let content =
                    candidate["content"] as? [String: Any],
                let parts =
                    content["parts"] as? [[String: Any]]
            else {
                return "I couldn't read the response."
            }

            let completeText = parts
                .compactMap { part in
                    part["text"] as? String
                }
                .joined(separator: "\n")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !completeText.isEmpty else {
                return "Gemini returned an empty response."
            }

            return completeText

        } catch is CancellationError {
            return ""

        } catch {
            print(
                "Gemini request failed:",
                error.localizedDescription
            )

            return "I couldn't connect right now."
        }
    }
}
