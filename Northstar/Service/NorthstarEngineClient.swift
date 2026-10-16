import Foundation
import Supabase

/// Sends the conversation to the Northstar Engine (Supabase function
/// "northstar-chat"), which asks Claude. No AI key lives in the app.
struct NorthstarEngineClient {

    /// A reply plus what came with it (stage, what was heard, save suggestions).
    struct EngineReply: Sendable {
        let text: String
        let insight: NorthstarInsight?
        /// True when Northstar couldn't answer (the message is an error, not a reply to keep).
        var failed: Bool = false
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

    /// Settings the brain turns into rules (answer length, name, visuals, memory).
    nonisolated private struct SettingsPayload: Encodable, Sendable {
        let answer_length: String
        let preferred_name: String
        /// Optional nickname the person gave Northstar (its name stays Northstar).
        let nickname: String
        /// Add-on modules this person switched on (e.g. "woodcarving").
        let modules: [String]
        let show_visuals: Bool
        let memory_on: Bool
        /// The phone's time zone (e.g. "America/Los_Angeles"), so "today" and "now" are right.
        let timezone: String
    }

    /// One photo sent with the latest message (base64 JPEG).
    nonisolated private struct Photo: Encodable, Sendable {
        let media_type: String
        let data: String
    }

    nonisolated private struct Request: Encodable, Sendable {
        let messages: [Turn]
        let memory: [MemoryItem]
        let corrections: [String]
        let settings: SettingsPayload?
        /// The saved chat this message belongs to (so notes can open their chat).
        let chat_id: String?
        /// A photo attached to the latest message, if any (only the newest photo is sent).
        let image: Photo?
        /// Their next 7 days of calendar, only when they asked about their schedule.
        let calendar: [CalendarLine]?
    }

    /// One calendar item sent when they ask about their schedule ("Today 2:00 PM: Vet").
    nonisolated struct CalendarLine: Encodable, Sendable {
        let title: String
        let when: String
        let location: String?
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
        corrections: [String] = [],
        settings: EngineSettings? = nil,
        chatId: UUID? = nil,
        calendar: [CalendarLine]? = nil
    ) async -> EngineReply {
        let settingsPayload = settings.map {
            SettingsPayload(
                answer_length: $0.answerLength.rawValue,
                preferred_name: $0.preferredName,
                nickname: $0.nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                modules: $0.modules,
                show_visuals: $0.showVisuals,
                memory_on: $0.memoryOn,
                timezone: TimeZone.current.identifier
            )
        }

        let turns = messages
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(60) // the brain reads the last 14 in full and keeps the rest as short lines
            .map { message -> Turn in
                // Northstar's past save offers ride along, so it never offers the same save twice.
                var content = message.content
                if message.role == .assistant, let saves = message.insight?.proposedSaves, !saves.isEmpty {
                    content += "\n\n(Offered to save: " + saves.map { "\u{201C}\($0.text)\u{201D}" }.joined(separator: "; ") + ")"
                }
                return Turn(role: message.role == .user ? "user" : "assistant", content: content)
            }

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
                        corrections: Array(corrections.prefix(10)),
                        settings: settingsPayload,
                        chat_id: chatId?.uuidString,
                        image: messages.last(where: { $0.role == .user })?.image.map {
                            Photo(media_type: "image/jpeg", data: $0.base64EncodedString())
                        },
                        calendar: calendar
                    )
                )
            )

            if let text = result.reply?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return EngineReply(text: text, insight: result.insight)
            }
            print("Northstar Engine error:", result.error ?? "empty reply")
            return EngineReply(text: "Northstar couldn't answer right now. Please try again.", insight: nil, failed: true)

        } catch is CancellationError {
            return EngineReply(text: "", insight: nil, failed: true)
        } catch {
            print("Northstar Engine request failed:", error.localizedDescription)
            return EngineReply(text: "I couldn't connect right now. Please try again.", insight: nil, failed: true)
        }
    }

    /// Text only (used by flows like the sitemap).
    func getResponse(for messages: [MessageModel]) async -> String {
        await getReply(for: messages).text
    }
}
