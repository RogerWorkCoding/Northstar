import Foundation

/// The extra things the Northstar Engine returns with a reply:
/// the stage, what it heard, and what it suggests saving.
nonisolated struct NorthstarInsight: Hashable, Sendable, Decodable {

    nonisolated struct Heard: Hashable, Sendable, Decodable {
        let group: String   // what | feeling | for | must | avoid
        let text: String

        /// Word label shown on the pill, so meaning never depends on color.
        var label: String {
            switch group {
            case "what": return "What"
            case "feeling": return "Feeling"
            case "for": return "For"
            case "must": return "Must"
            case "avoid": return "Avoid"
            default: return group.capitalized
            }
        }
    }

    nonisolated struct Save: Hashable, Sendable, Decodable {
        let kind: String    // destination | decision | next_step | taste | open_question
        let text: String
        let reason: String

        /// Card title, e.g. "SAVE AS YOUR DESTINATION?"
        var question: String {
            switch kind {
            case "destination": return "Save as your destination?"
            case "decision": return "Save this decision?"
            case "next_step": return "Save as your next step?"
            case "taste": return "Remember this preference?"
            case "open_question": return "Keep this question open?"
            default: return "Save this?"
            }
        }

        /// Confirmation line after saving.
        var savedLine: String {
            switch kind {
            case "destination": return "Saved as your destination"
            case "decision": return "Decision saved"
            case "next_step": return "Next step saved"
            case "taste": return "Preference saved"
            case "open_question": return "Question saved"
            default: return "Saved"
            }
        }
    }

    /// A simple wireframe (drawing only) for visual requests like a web page.
    nonisolated struct Visual: Hashable, Sendable, Decodable {
        let title: String
        let svg: String
    }

    /// A web page Northstar used for its answer (checked on the server: real search results only).
    nonisolated struct Source: Hashable, Sendable, Decodable {
        let title: String
        let url: URL

        /// Site name for the link, written like a name: "Dell.com", "Weather.gov".
        var site: String {
            let host = (url.host() ?? title).replacingOccurrences(of: "www.", with: "")
            return host.prefix(1).uppercased() + host.dropFirst()
        }
    }

    /// One look to react to: name, mood, keywords, colors and a type style.
    nonisolated struct Direction: Hashable, Sendable, Decodable {
        let name: String
        let mood: String
        let keywords: [String]
        let palette: [String]   // "#RRGGBB"
        let typeStyle: String   // serif | sans | rounded | mono | script

        enum CodingKeys: String, CodingKey {
            case name, mood, keywords, palette
            case typeStyle = "type_style"
        }
    }

    let stage: String?
    let stageReason: String?
    let destination: String?
    let heard: [Heard]
    let proposedSaves: [Save]
    let visual: Visual?
    /// Safety path: the person may be in crisis. The app shows real help first.
    let crisis: Bool
    /// "Show options instead of asking": three directions, or none.
    let directions: [Direction]
    /// Web pages used for this answer (empty when Northstar didn't look anything up).
    let sources: [Source]

    /// Approved design rule: stage, pills and save cards only show when
    /// Northstar is guiding. Quick questions get just the answer.
    var isGuiding: Bool {
        destination != nil || !proposedSaves.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case stage
        case stageReason = "stage_reason"
        case destination
        case heard
        case proposedSaves = "proposed_saves"
        case visual
        case crisis
        case directions
        case sources
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decodeIfPresent(String.self, forKey: .stage)
        stageReason = try c.decodeIfPresent(String.self, forKey: .stageReason)
        destination = try c.decodeIfPresent(String.self, forKey: .destination)
        heard = (try? c.decodeIfPresent([Heard].self, forKey: .heard)) ?? []
        proposedSaves = (try? c.decodeIfPresent([Save].self, forKey: .proposedSaves)) ?? []
        visual = try? c.decodeIfPresent(Visual.self, forKey: .visual)
        crisis = (try? c.decodeIfPresent(Bool.self, forKey: .crisis)) ?? false
        directions = (try? c.decodeIfPresent([Direction].self, forKey: .directions)) ?? []
        // Only https links are shown.
        // Only https links, and one per site (the brain also does this).
        var seenSites = Set<String>()
        sources = ((try? c.decodeIfPresent([Source].self, forKey: .sources)) ?? [])
            .filter { $0.url.scheme == "https" && seenSites.insert($0.site).inserted }
    }
}
