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
    /// A calendar event or reminder Northstar offers to add (added only when they tap Add).
    nonisolated struct Schedule: Hashable, Sendable, Decodable {
        let kind: String          // event | reminder
        let title: String
        let date: String          // YYYY-MM-DD (their local date)
        let time: String          // HH:MM, 24-hour (their local time)
        let minutes: Int?         // event length
        let alertMinutes: Int?    // alert this many minutes before (events)
        let location: String?
        let repeatRule: String?   // daily | weekly | monthly | yearly
        enum CodingKeys: String, CodingKey {
            case kind, title, date, time, minutes, location
            case alertMinutes = "alert_minutes"
            case repeatRule = "repeat"
        }
        var isEvent: Bool { kind == "event" }

        /// The start, in the phone's time zone.
        var start: Date? {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return f.date(from: "\(date) \(time)")
        }

        /// "Tomorrow at 3:00 PM" / "Fri, Oct 23 at 9:00 AM"
        var whenText: String {
            guard let start else { return "\(date) \(time)" }
            let cal = Calendar.current
            let t = start.formatted(date: .omitted, time: .shortened)
            if cal.isDateInToday(start) { return "Today at \(t)" }
            if cal.isDateInTomorrow(start) { return "Tomorrow at \(t)" }
            return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) + " at \(t)"
        }
    }

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
        /// Concierge: one line on why it fits this person.
        var why: String? = nil
        /// Concierge: something happening today, with where it came from and how fresh.
        var tonight: Tonight? = nil

        nonisolated struct Tonight: Hashable, Sendable, Decodable {
            let text: String
            let source: String
            let posted: String
            let url: URL
        }
    }

    /// A product to compare (Concierge shopping): name, price, store, rating, why, and its page.
    nonisolated struct Product: Hashable, Sendable, Decodable {
        let name: String
        let price: String?
        let store: String?
        let rating: String?
        let why: String?
        let url: URL
    }

    /// A rental listing (Concierge apartments): real link, true monthly cost and a scam check.
    nonisolated struct Listing: Hashable, Sendable, Decodable, Identifiable {
        var id: URL { url }
        let name: String
        let url: URL
        let rent: Double
        var area: String? = nil
        var beds: Double? = nil
        var baths: Double? = nil
        var sqft: Double? = nil
        var source: String? = nil
        var posted: String? = nil
        var why: String? = nil
        var trueCost: TrueCost? = nil
        let scam: ScamCheck

        nonisolated struct TrueCost: Hashable, Sendable, Decodable {
            let total: Double
            let parts: [String]
        }
        nonisolated struct ScamCheck: Hashable, Sendable, Decodable {
            let level: String      // clear · caution · warning
            let reasons: [String]
        }

        /// "2 bd · 1 ba · 850 sq ft"
        var sizeText: String {
            var bits: [String] = []
            if let beds { bits.append(beds == 0 ? "Studio" : "\(Self.n(beds)) bd") }
            if let baths { bits.append("\(Self.n(baths)) ba") }
            if let sqft, sqft > 0 { bits.append("\(Int(sqft).formatted()) sq ft") }
            return bits.joined(separator: " \u{00B7} ")
        }
        static func money(_ v: Double) -> String { "$" + Int(v.rounded()).formatted() }
        private static func n(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
    }

    /// The expert behind the answer (a skill like Design, or a switched-on module like Wood carving).
    nonisolated struct Used: Hashable, Sendable, Decodable {
        let expert: String
        let module: Bool?
    }

    /// What they've said so far for a table or appointment (fills the Reserve and Call buttons).
    nonisolated struct Booking: Hashable, Sendable, Decodable {
        var party: Int?
        var date: String?   // YYYY-MM-DD
        var time: String?   // HH:MM, 24-hour

        /// Keeps earlier details when a new reply leaves them out.
        func merged(with newer: Booking?) -> Booking {
            Booking(party: newer?.party ?? party, date: newer?.date ?? date, time: newer?.time ?? time)
        }

        var start: Date? {
            guard let date else { return nil }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return f.date(from: "\(date) \(time ?? "19:00")")
        }

        /// "Saturday" / "tonight" / "Oct 24", for the call script.
        var dayText: String? {
            guard let start else { return nil }
            let cal = Calendar.current
            if cal.isDateInToday(start) { return "tonight" }
            if cal.isDateInTomorrow(start) { return "tomorrow" }
            if let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: start).day, days < 7 {
                return start.formatted(.dateTime.weekday(.wide))
            }
            return start.formatted(.dateTime.month(.abbreviated).day())
        }

        var timeText: String? {
            guard time != nil, let start else { return nil }
            return start.formatted(date: .omitted, time: .shortened)
        }
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
    /// Products to compare (Concierge shopping; empty otherwise).
    let products: [Product]
    /// Booking details (Concierge; nil otherwise).
    let booking: Booking?
    /// Apartment listings with a scam check (Concierge; empty otherwise).
    let listings: [Listing]
    /// The expert the brain used (nil for plain chat, personal moments and crisis).
    let used: Used?
    /// ✦ Deep Think: the bigger brain thought this through.
    var deep = false
    /// Deep Think answers left today (nil when the question didn't need one).
    var deepLeft: Int? = nil

    /// The quiet line at the end of an answer: "Wood carving · looked at 3 sources".
    /// Only what really happened; nil when nothing special did (so plain chat stays clean).
    var usedLine: String? {
        guard !crisis else { return nil }
        var parts: [String] = []
        if deep {
            parts.append("Deep Think" + (deepLeft.map { " (\($0) left today)" } ?? ""))
        } else if deepLeft == 0 {
            parts.append("Deep Think is used up for today")
        }
        if let used { parts.append(used.expert) }
        if !sources.isEmpty { parts.append("looked at \(sources.count) source\(sources.count == 1 ? "" : "s")") }
        if !places.isEmpty { parts.append("\(places.count) on the map") }
        if visual != nil { parts.append("sketched a layout") }
        guard let first = parts.first else { return nil }
        parts[0] = first.prefix(1).uppercased() + first.dropFirst()
        return parts.joined(separator: " · ")
    }
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
    /// A calendar event or reminder to offer (nil for most replies).
    let schedule: Schedule?

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
        case products
        case listings
        case booking
        case used
        case deep
        case deepLeft = "deep_left"
        case shots
        case videos
        case code
        case folderHint = "folder_hint"
        case fromBefore = "from_before"
        case subjectOffer = "subject_offer"
        case chatTitle = "chat_title"
        case subjectUpdate = "subject_update"
        case schedule
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
        products = Array(((try? c.decodeIfPresent([Product].self, forKey: .products)) ?? [])
            .filter { $0.url.scheme == "https" }
            .prefix(3))
        booking = try? c.decodeIfPresent(Booking.self, forKey: .booking)
        listings = Array(((try? c.decodeIfPresent([Listing].self, forKey: .listings)) ?? [])
            .filter { $0.url.scheme == "https" }
            .prefix(3))
        used = try? c.decodeIfPresent(Used.self, forKey: .used)
        deep = (try? c.decodeIfPresent(Bool.self, forKey: .deep)) ?? false
        deepLeft = (try? c.decodeIfPresent(Int.self, forKey: .deepLeft)) ?? nil
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
        schedule = try? c.decodeIfPresent(Schedule.self, forKey: .schedule)
    }
}
