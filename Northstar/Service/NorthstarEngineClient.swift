import Foundation
import Supabase

/// Sends the conversation to the Northstar Engine (Supabase function
/// "northstar-chat"), which asks Claude. No AI key lives in the app.
struct NorthstarEngineClient {

    /// A reply plus what came with it (stage, what was heard, save suggestions).
    struct EngineReply: Sendable {
        let text: String
        let insight: NorthstarInsight?
    }

    nonisolated private struct Turn: Encodable, Sendable {
        let role: String
        let content: String
    }

    /// One confirmed memory sent to the brain (kind + text only).
    nonisolated struct MemoryItem: Encodable, Sendable {
        let kind: String
        let text: String
    }

    nonisolated private struct Request: Encodable, Sendable {
        let messages: [Turn]
        let memory: [MemoryItem]
        let corrections: [String]
    }

    nonisolated private struct Reply: Decodable, Sendable {
        let reply: String?
        let error: String?
        let insight: NorthstarInsight?

        enum CodingKeys: String, CodingKey { case reply, error }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            reply = try c.decodeIfPresent(String.self, forKey: .reply)
            error = try c.decodeIfPresent(String.self, forKey: .error)
            insight = try? NorthstarInsight(from: decoder)
        }
    }

    /// Full reply with stage, pills and save suggestions.
    func getReply(
        for messages: [MessageModel],
        memory: [MemoryItem] = [],
        corrections: [String] = []
    ) async -> EngineReply {
        let turns = messages
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(20)
            .map { Turn(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        guard turns.last?.role == "user" else {
            return EngineReply(text: "Ask me something and I'll help.", insight: nil)
        }

        do {
            let result: Reply = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-chat",
                options: FunctionInvokeOptions(
                    body: Request(
                        messages: Array(turns),
                        memory: Array(memory.prefix(20)),
                        corrections: Array(corrections.prefix(10))
                    )
                )
            )

            if let text = result.reply?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return EngineReply(text: text, insight: result.insight)
            }
            print("Northstar Engine error:", result.error ?? "empty reply")
            return EngineReply(text: "Northstar couldn't answer right now. Please try again.", insight: nil)

        } catch is CancellationError {
            return EngineReply(text: "", insight: nil)
        } catch {
            print("Northstar Engine request failed:", error.localizedDescription)
            return EngineReply(text: "I couldn't connect right now. Please try again.", insight: nil)
        }
    }

    /// Text only (used by flows like the sitemap).
    func getResponse(for messages: [MessageModel]) async -> String {
        await getReply(for: messages).text
    }
}
