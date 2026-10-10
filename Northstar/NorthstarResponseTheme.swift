import SwiftUI

/// Visual tokens scoped to the structured-response hierarchy feature. These intentionally
/// reuse ChatBubbleView's existing pill fill rather than introducing a new app-wide palette.
enum NorthstarResponseTheme {
    static let warmWhite = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let charcoal = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let goldAccent = Color(red: 0.74, green: 0.61, blue: 0.30)

    static let pillFill = Color.white.opacity(0.35)
    static let pillBorder = Color.white.opacity(0.18)
    static let pillShadow = Color.black.opacity(0.14)

    static let recommendationFill = goldAccent.opacity(0.14)
    static let recommendationBorder = goldAccent.opacity(0.4)

    static let labelFill = Color.white.opacity(0.16)

    enum Typography {
        /// Prominent but still conversational — heavier than detail text, lighter than the title.
        static let directAnswer = Font.body.weight(.medium)
        /// The strongest text in the pill; clearly outranks section headings and the recommendation.
        static let title = Font.title2.weight(.bold)
        static let introduction = Font.body
        static let introductionLineSpacing: CGFloat = 4
        static let sectionHeading = Font.headline.weight(.semibold)
        static let sectionHeadingTopSpacing: CGFloat = 6
        static let body = Font.body
        static let lead = Font.body.weight(.semibold)
        static let detail = Font.body
        static let label = Font.caption2.weight(.medium)
        static let recommendationHeading = Font.subheadline.weight(.semibold)
        static let recommendationBody = Font.subheadline
    }
}
