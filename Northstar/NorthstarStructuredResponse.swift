import Foundation

// Source of truth boundary: this model is the permanent target shape. Today it is populated
// by NorthstarResponseParser from plain-text Markdown-ish content (the compatibility flow).
// When the backend starts returning structured JSON directly, that JSON should decode straight
// into NorthstarStructuredResponse (it's Codable) and bypass NorthstarResponseParser entirely —
// NorthstarStructuredResponseView never needs to know which flow produced its input.
struct NorthstarStructuredResponse: Hashable, Sendable, Codable {
    var directAnswer: String?
    var title: String?
    var labels: [String]
    var introduction: String?
    var sections: [NorthstarResponseSection]
    var recommendedAction: NorthstarResponseItem?
    /// Lets a future backend dictate presentation directly instead of relying on classify(_:).
    var explicitDensity: NorthstarResponseDensity?

    init(
        directAnswer: String? = nil,
        title: String? = nil,
        labels: [String] = [],
        introduction: String? = nil,
        sections: [NorthstarResponseSection] = [],
        recommendedAction: NorthstarResponseItem? = nil,
        explicitDensity: NorthstarResponseDensity? = nil
    ) {
        self.directAnswer = directAnswer
        self.title = title
        self.labels = labels
        self.introduction = introduction
        self.sections = sections
        self.recommendedAction = recommendedAction
        self.explicitDensity = explicitDensity
    }

    var density: NorthstarResponseDensity {
        explicitDensity ?? NorthstarResponseDensity.classify(self)
    }

    /// Whether this response carries any hierarchy at all — when false, callers should render
    /// the original plain text rather than this structured view.
    var hasStructure: Bool {
        directAnswer != nil || title != nil || introduction != nil || !sections.isEmpty || recommendedAction != nil
    }
}

struct NorthstarResponseSection: Hashable, Sendable, Codable {
    var heading: String?
    var body: String?
    var items: [NorthstarResponseItem]

    init(heading: String? = nil, body: String? = nil, items: [NorthstarResponseItem] = []) {
        self.heading = heading
        self.body = body
        self.items = items
    }
}

struct NorthstarResponseItem: Hashable, Sendable, Codable {
    var lead: String?
    var detail: String

    init(lead: String? = nil, detail: String) {
        self.lead = lead
        self.detail = detail
    }
}

enum NorthstarResponseDensity: String, Hashable, Sendable, Codable {
    case compact
    case standard
    case expanded

    /// Classifies by semantic structure first; raw length only breaks ties when no
    /// structure exists at all, and never promotes a response past .standard on its own.
    static func classify(_ response: NorthstarStructuredResponse) -> NorthstarResponseDensity {
        let hasTitle = !(response.title?.isEmpty ?? true)
        let hasIntroduction = !(response.introduction?.isEmpty ?? true)
        let sectionCount = response.sections.count
        let headingCount = response.sections.filter { !($0.heading?.isEmpty ?? true) }.count
        let itemCount = response.sections.reduce(0) { $0 + $1.items.count }
        let hasRecommendation = response.recommendedAction != nil

        let structureScore = (hasTitle ? 1 : 0)
            + sectionCount
            + headingCount
            + (itemCount >= 3 ? 1 : 0)
            + (hasRecommendation ? 1 : 0)

        if structureScore >= 3 || (sectionCount >= 2 && hasRecommendation) {
            return .expanded
        }
        if structureScore >= 1 || hasIntroduction || itemCount > 0 {
            return .standard
        }

        let fallbackLength = (response.directAnswer?.count ?? 0) + (response.introduction?.count ?? 0)
        return fallbackLength > 280 ? .standard : .compact
    }
}
