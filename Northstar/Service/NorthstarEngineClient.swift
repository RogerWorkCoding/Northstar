import Foundation
import Supabase

/// Sends the conversation to the Northstar Engine (Supabase function
/// "northstar-chat"), which asks Claude. No AI key lives in the app.
struct NorthstarEngineClient {

    nonisolated private struct Turn: Encodable, Sendable {
        let role: String
        let content: String
    }

    nonisolated private struct Request: Encodable, Sendable {
        let messages: [Turn]
    }

    nonisolated private struct Reply: Decodable, Sendable {
        let reply: String?
        let error: String?
    }

    /// Same shape as the old GeminiProvider, so the chat screen can swap it in.
    func getResponse(for messages: [MessageModel]) async -> String {
        let turns = messages
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(20)
            .map { Turn(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        guard turns.last?.role == "user" else {
            return "Ask me something and I'll help."
        }

        do {
            let result: Reply = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-chat",
                options: FunctionInvokeOptions(body: Request(messages: Array(turns)))
            )

            if let text = result.reply?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
            print("Northstar Engine error:", result.error ?? "empty reply")
            return "Northstar couldn't answer right now. Please try again."

        } catch is CancellationError {
            return ""
        } catch {
            print("Northstar Engine request failed:", error.localizedDescription)
            return "I couldn't connect right now. Please try again."
        }
    }
}
