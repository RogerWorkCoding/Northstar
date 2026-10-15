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

    /// A new subject Northstar offers to keep ("Keep this?").
    nonisolated struct SubjectOffer: Hashable, Sendable, Decodable {
        let title: String
        let goal: String?
        let nextStep: String?
        enum CodingKeys: String, CodingKey { case title, goal; case nextStep = "next_step" }
    }

    /// A kept subject Northstar just updated, with what it was before (for Undo).
    nonisolated struct SubjectUpdate: Hashable, Sendable, Decodable {
        nonisolated struct Snapshot: Hashable, Sendable, Decodable {
            let goal: String?
            let nextStep: String?
            let decisions: [SubjectDecision]
            let status: String
            enum CodingKeys: String, CodingKey { case goal, decisions, status; case nextStep = "next_step" }
        }
        let id: UUID
        let title: String
        let changes: [String]
        /// When this change was written; Undo only applies if the card hasn't changed since.
        let stamp: String
        let undo: Snapshot
    }

    /// A simple wireframe (drawing only) for visual requests like a web page.
    nonisolated struct Visual: Hashable, Sendable, Decodable {
        let title: String
        let svg: String
    }

    /// A web page Northstar used for its answer (checked on the server: real search results only).
    /// A real YouTube lesson the brain found (modules like Wood carving).
    nonisolated struct LessonVideo: Hashable, Sendable, Decodable, Identifiable {
        let id: String      // YouTube video id
        let title: String
        let url: String
    }

    /// A code card from the Coding module: shown in a monospace box with a Copy button.
    nonisolated struct CodeSnippet: Hashable, Sendable, Decodable {
        let title: String
        let language: String
        let code: String
        let explain: String
    }

    /// A video shot card: paste the prompt into a video tool like Google Flow.
    nonisolated struct Shot: Hashable, Sendable, Decodable {
        let title: String
        let seconds: Int
        let framing: String
        let prompt: String
    }

    /// A real place Northstar recommends; the app finds it in Apple Maps.
    nonisolated struct Place: Hashable, Sendable, Decodable {
        let name: String
        let area: String
    }

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
    /// Real places to show on a map (empty for most replies).
    let places: [Place]
    /// Video shot cards (empty unless they're making a video).
    let shots: [Shot]
    /// YouTube lessons to watch in the app (empty unless a module found some).
    let videos: [LessonVideo]
    /// Code cards (empty unless the Coding module is on).
    let code: [CodeSnippet]
    /// Northstar's suggested folder for saving the videos (the person chooses).
    let folderHint: String?
    /// A line from an earlier conversation that matches (shown as a "From before" card).
    let fromBefore: [Note]
    /// Subjects: a new one to keep, or a kept one that was just updated.
    let subjectOffer: SubjectOffer?
    /// First reply of a chat only: a short name for it (2–5 words), used in History.
    let chatTitle: String?
    let subjectUpdate: SubjectUpdate?

    /// Approved design rule: stage, pills and save cards only show when
    /// Northstar is guiding. Quick questions get just the answer.
    var isGuiding: Bool {
        destination != nil || !proposedSaves.isEmpty || subjectOffer != nil || subjectUpdate != nil
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
        case places
        case shots
        case videos
        case code
        case folderHint = "folder_hint"
        case fromBefore = "from_before"
        case subjectOffer = "subject_offer"
        case chatTitle = "chat_title"
        case subjectUpdate = "subject_update"
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
        places = Array(((try? c.decodeIfPresent([Place].self, forKey: .places)) ?? []).prefix(5))
        shots = Array(((try? c.decodeIfPresent([Shot].self, forKey: .shots)) ?? []).prefix(5))
        videos = Array(((try? c.decodeIfPresent([LessonVideo].self, forKey: .videos)) ?? [])
            .filter { $0.id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil }
            .prefix(3))
        folderHint = try? c.decodeIfPresent(String.self, forKey: .folderHint)
        code = Array(((try? c.decodeIfPresent([CodeSnippet].self, forKey: .code)) ?? [])
            .filter { !$0.code.isEmpty }
            .prefix(3))
        fromBefore = (try? c.decodeIfPresent([Note].self, forKey: .fromBefore)) ?? []
        subjectOffer = try? c.decodeIfPresent(SubjectOffer.self, forKey: .subjectOffer)
        chatTitle = try? c.decodeIfPresent(String.self, forKey: .chatTitle)
        subjectUpdate = try? c.decodeIfPresent(SubjectUpdate.self, forKey: .subjectUpdate)
    }
}
