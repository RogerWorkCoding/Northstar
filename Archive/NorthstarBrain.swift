// Archived OpenAI implementation.
// The original OpenAI credential was revoked and removed.
// This file is preserved for historical reference only.
// A secure backend credential system would be required before reuse.
//
// This file is NOT part of the Northstar app target and is not compiled.

import Foundation

struct NorthstarBrain {
    private let intelligence = NorthstarIntelligence()
    // Archived OpenAI implementation.
    // The original OpenAI credential was revoked and removed.
    // This file is preserved for historical reference only.
    // A secure backend credential system would be required before reuse.
    private let model = "gpt-4o-mini"

    func getResponse(
        for messages: [MessageModel]
    ) async -> String {
        guard let latestMessage = messages.last?.content else {
            return ""
        }

        let intent = intelligence.detectIntent(
            from: latestMessage
        )

        print("⭐ Northstar Intent:", intent)

        guard let url = URL(
            string: "https://api.openai.com/v1/chat/completions"
        ) else {
            return "I couldn't start the request."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        let systemMessage: [String: String] = [
            "role": "system",
            "content": """
            You are Northstar, one unified intelligent guide.

            Users must never be asked to choose:
            - an expertise level
            - a persona
            - an AI model
            - a knowledge tier
            - a junior, senior, or creative director mode

            Intelligently determine which knowledge areas are relevant
            to the user's goal.

            Relevant disciplines may include:
            - Exploration
            - Craft
            - Vision
            - Build
            - Intelligence
            - Architecture
            - Branding
            - UX design
            - Web development
            - Product strategy

            Combine the relevant disciplines internally and respond as
            one unified Northstar.

            Guide the user clearly without overwhelming them.
            Give practical next actions.
            Preserve project context.
            Do not expose internal personas or expertise levels.

            Northstar's guiding principle is:
            One clear destination. An intelligent path forward.
            """
        ]

        let conversation: [[String: String]] =
            messages.map { message in
                [
                    "role":
                        message.role == .user
                        ? "user"
                        : "assistant",

                    "content":
                        message.content
                ]
            }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [systemMessage] + conversation,
            "temperature": 0.7,
            "max_tokens": 1200
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
                "OpenAI status:",
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
                        "OpenAI API error:",
                        errorText
                    )
                }

                if httpResponse.statusCode == 429 {
                    return """
                    Northstar has reached the current request limit.
                    Please try again shortly.
                    """
                }

                if httpResponse.statusCode == 503 {
                    return """
                    The AI service is currently busy.
                    Please try again shortly.
                    """
                }

                return "I couldn't complete that request."
            }

            guard
                let json =
                    try JSONSerialization.jsonObject(
                        with: data
                    ) as? [String: Any],

                let choices =
                    json["choices"]
                        as? [[String: Any]],

                let firstChoice = choices.first,

                let message =
                    firstChoice["message"]
                        as? [String: Any],

                let content =
                    message["content"] as? String
            else {
                return "I couldn't read the response."
            }

            let cleanedResponse =
                content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !cleanedResponse.isEmpty else {
                return "The AI service returned an empty response."
            }

            return cleanedResponse

        } catch is CancellationError {
            return ""

        } catch {
            print(
                "OpenAI request failed:",
                error.localizedDescription
            )

            return "I couldn't connect right now."
        }
    }
}
