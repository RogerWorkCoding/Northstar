import SwiftUI

/// Renders the editorial hierarchy — direct answer, labels, title, introduction,
/// sections, recommendation — inside whatever pill NorthstarResponseContainer provides.
struct NorthstarStructuredResponseView: View {
    let response: NorthstarStructuredResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let directAnswer = response.directAnswer, !directAnswer.isEmpty {
                Text(directAnswer)
                    .font(NorthstarResponseTheme.Typography.directAnswer)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !response.labels.isEmpty {
                NorthstarResponseLabelRow(labels: response.labels)
            }

            if let title = response.title, !title.isEmpty {
                Text(title)
                    .font(NorthstarResponseTheme.Typography.title)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            if let introduction = response.introduction, !introduction.isEmpty {
                Text(introduction)
                    .font(NorthstarResponseTheme.Typography.introduction)
                    .lineSpacing(NorthstarResponseTheme.Typography.introductionLineSpacing)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(response.sections.enumerated()), id: \.offset) { _, section in
                NorthstarResponseSectionView(section: section)
            }

            if let recommendedAction = response.recommendedAction {
                NorthstarRecommendationView(item: recommendedAction)
            }
        }
    }
}

/// Secondary navigation aids only — kept visually quieter than the title/headings above.
struct NorthstarResponseLabelRow: View {
    let labels: [String]

    var body: some View {
        NorthstarLabelFlowLayout(spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(NorthstarResponseTheme.Typography.label)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(NorthstarResponseTheme.labelFill))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Topics: \(labels.joined(separator: ", "))"))
    }
}

struct NorthstarResponseSectionView: View {
    let section: NorthstarResponseSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading = section.heading, !heading.isEmpty {
                Text(heading)
                    .font(NorthstarResponseTheme.Typography.sectionHeading)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, NorthstarResponseTheme.Typography.sectionHeadingTopSpacing)
                    .accessibilityAddTraits(.isHeader)
            }

            if let body = section.body, !body.isEmpty {
                Text(body)
                    .font(NorthstarResponseTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !section.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        NorthstarResponseItemRow(item: item)
                    }
                }
            }
        }
    }
}

/// Builds a bold-lead + regular-detail run as a single AttributedString rather than
/// concatenating two Text views (deprecated in iOS 26 in favor of this approach).
private func leadDetailAttributedString(
    lead: String,
    detail: String,
    leadFont: Font,
    detailFont: Font
) -> AttributedString {
    var leadRun = AttributedString(lead)
    leadRun.font = leadFont
    var detailRun = AttributedString(" \(detail)")
    detailRun.font = detailFont
    return leadRun + detailRun
}

private struct NorthstarResponseItemRow: View {
    let item: NorthstarResponseItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Group {
                if let lead = item.lead, !lead.isEmpty {
                    Text(leadDetailAttributedString(
                        lead: lead,
                        detail: item.detail,
                        leadFont: NorthstarResponseTheme.Typography.lead,
                        detailFont: NorthstarResponseTheme.Typography.detail
                    ))
                    .foregroundStyle(.white.opacity(0.92))
                } else {
                    Text(item.detail)
                        .font(NorthstarResponseTheme.Typography.detail)
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Guidance, not a promotional callout: a tonal gold background and leading heading,
/// staying inside the parent pill rather than floating as its own card.
struct NorthstarRecommendationView: View {
    let item: NorthstarResponseItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next Recommended Action")
                .font(NorthstarResponseTheme.Typography.recommendationHeading)
                .foregroundStyle(NorthstarResponseTheme.goldAccent)
                .accessibilityAddTraits(.isHeader)

            if let lead = item.lead, !lead.isEmpty {
                Text(leadDetailAttributedString(
                    lead: lead,
                    detail: item.detail,
                    leadFont: NorthstarResponseTheme.Typography.recommendationBody.weight(.semibold),
                    detailFont: NorthstarResponseTheme.Typography.recommendationBody
                ))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(item.detail)
                    .font(NorthstarResponseTheme.Typography.recommendationBody)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NorthstarResponseTheme.recommendationFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(NorthstarResponseTheme.recommendationBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Minimal wrapping row for label chips — SwiftUI has no built-in flow layout.
private struct NorthstarLabelFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > bounds.minX, point.x + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: point, anchor: .topLeading, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NorthstarResponseContainer(isUser: false, density: .expanded) {
        NorthstarStructuredResponseView(
            response: NorthstarStructuredResponse(
                directAnswer: "Project Memory keeps continuity across every session.",
                title: "How Northstar Remembers",
                labels: ["Foundation", "Memory", "Architecture"],
                introduction: "Northstar blends three memory layers so guidance stays relevant as a project evolves.",
                sections: [
                    NorthstarResponseSection(
                        heading: "Foundation",
                        items: [
                            NorthstarResponseItem(lead: "Project Memory", detail: "stores goals, progress, blockers, and the current stage."),
                            NorthstarResponseItem(lead: "Identity Memory", detail: "captures voice, tone, and recurring preferences.")
                        ]
                    ),
                    NorthstarResponseSection(
                        heading: "Architecture",
                        body: "Each layer is written independently and merged only at response time.",
                        items: [
                            NorthstarResponseItem(detail: "Reads happen before every reply."),
                            NorthstarResponseItem(detail: "Writes happen only after explicit confirmation.")
                        ]
                    )
                ],
                recommendedAction: NorthstarResponseItem(
                    lead: "Review your Project Memory",
                    detail: "to confirm the current stage still matches reality."
                )
            )
        )
    }
    .padding(.vertical)
    .background(Color(red: 0.08, green: 0.12, blue: 0.25))
}
