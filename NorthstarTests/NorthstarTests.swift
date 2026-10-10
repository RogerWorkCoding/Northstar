//
//  NorthstarTests.swift
//  NorthstarTests
//
//  Created by Roger Ward on 10/10/26.
//

import Foundation
import Testing
@testable import Northstar

struct NorthstarResponseParserTests {

    @Test func plainShortTextRemainsCompact() {
        let response = NorthstarResponseParser.parse("Sure, here's a quick note.")
        #expect(response.density == .compact)
    }

    @Test func headingWithShortListBecomesStandard() {
        let text = """
        ## Quick Overview
        Here is a short summary.
        - First point
        - Second point
        """
        let response = NorthstarResponseParser.parse(text)
        #expect(response.title == "Quick Overview")
        #expect(response.introduction == "Here is a short summary.")
        #expect(response.density == .standard)
    }

    @Test func multipleSectionsWithRecommendationBecomeExpanded() {
        let text = """
        ## Project Memory Overview
        Project memory keeps context across sessions.

        ## Foundation
        - **Project Memory** stores goals, progress, blockers, and the current stage.
        - Identity Memory captures tone.

        ## Architecture
        Some architecture body text.
        - Point A
        - Point B

        ## Next Recommended Action
        Review your current project memory entry and confirm the stage is accurate.
        """
        let response = NorthstarResponseParser.parse(text)
        #expect(response.sections.count == 2)
        #expect(response.recommendedAction != nil)
        #expect(response.density == .expanded)
    }

    @Test func boldLeadInIsSeparatedFromSupportingDetail() {
        let text = """
        ## Foundation
        - **Project Memory** stores goals, progress, blockers, and the current stage.
        """
        let response = NorthstarResponseParser.parse(text)
        let item = response.sections.first?.items.first
        #expect(item?.lead == "Project Memory")
        #expect(item?.detail == "stores goals, progress, blockers, and the current stage.")
    }

    @Test func labelsLineFormatParsesCorrectly() {
        let text = "Labels: Foundation, Memory, Architecture\n\nSome reply text."
        let response = NorthstarResponseParser.parse(text)
        #expect(response.labels == ["Foundation", "Memory", "Architecture"])
    }

    @Test func bracketedLabelsLineFormatParsesCorrectly() {
        let text = "[Foundation] [Memory] [Architecture]\n\nSome reply text."
        let response = NorthstarResponseParser.parse(text)
        #expect(response.labels == ["Foundation", "Memory", "Architecture"])
    }

    @Test func ordinaryBracketedTextIsNotMistakenForLabels() {
        let text = "[Draft] this is not actually a labels line because there's trailing prose"
        let response = NorthstarResponseParser.parse(text)
        #expect(response.labels.isEmpty)
    }

    @Test func recommendedActionHeadingIsExtractedCorrectly() {
        let text = """
        Just a plain note.

        ## Next Recommended Action
        Take a look at your settings.
        """
        let response = NorthstarResponseParser.parse(text)
        #expect(response.recommendedAction?.detail == "Take a look at your settings.")
        #expect(response.sections.isEmpty)
    }

    @Test func malformedUnmatchedBoldMarkerFallsBackSafely() {
        let text = "This has an **unmatched bold marker and should not crash."
        let response = NorthstarResponseParser.parse(text)
        #expect(response.directAnswer?.contains("**") == false)
    }

    @Test func malformedBoldInsideBulletFallsBackSafely() {
        let text = """
        ## Notes
        - **Incomplete lead with no closing marker
        """
        let response = NorthstarResponseParser.parse(text)
        let item = response.sections.first?.items.first
        #expect(item?.lead == nil)
        #expect(item?.detail.contains("**") == false)
    }

    @Test func emptyContentDoesNotCrash() {
        let response = NorthstarResponseParser.parse("")
        #expect(response.hasStructure == false)
        #expect(response.density == .compact)
    }

    @Test func whitespaceOnlyContentDoesNotCrash() {
        let response = NorthstarResponseParser.parse("   \n\n\t  ")
        #expect(response.hasStructure == false)
        #expect(response.density == .compact)
    }
}

struct NorthstarResponseDensityTests {

    @Test func densityClassifierPrioritizesStructureOverLength() {
        let richlyStructured = NorthstarStructuredResponse(
            title: "A",
            sections: [
                NorthstarResponseSection(
                    heading: "B",
                    items: [
                        NorthstarResponseItem(detail: "1"),
                        NorthstarResponseItem(detail: "2"),
                        NorthstarResponseItem(detail: "3")
                    ]
                ),
                NorthstarResponseSection(heading: "C")
            ],
            recommendedAction: NorthstarResponseItem(detail: "go")
        )
        #expect(richlyStructured.density == .expanded)

        let longButUnstructured = NorthstarStructuredResponse(
            directAnswer: String(repeating: "word ", count: 100)
        )
        #expect(longButUnstructured.density != .expanded)
    }

    @Test func explicitDensityOverridesClassification() {
        let response = NorthstarStructuredResponse(directAnswer: "Short.", explicitDensity: .expanded)
        #expect(response.density == .expanded)
    }
}

struct ChatBubbleViewStructuredResponseTests {

    @Test func userMessagesStayPlainEvenWithStructuredContent() {
        let richText = """
        ## Heading
        Some intro text.
        - item one
        - item two

        ## Next Recommended Action
        Do the thing.
        """
        let bubble = ChatBubbleView(id: UUID(), text: richText, isUser: true)
        #expect(bubble.structuredResponse == nil)
    }

    @Test func assistantCompactReplyStaysPlain() {
        let bubble = ChatBubbleView(id: UUID(), text: "Sure, here's a quick note.", isUser: false)
        #expect(bubble.structuredResponse == nil)
    }

    @Test func assistantStructuredReplyProducesStructuredResponse() {
        let richText = """
        ## Heading
        Some intro text.
        - item one
        - item two

        ## Next Recommended Action
        Do the thing.
        """
        let bubble = ChatBubbleView(id: UUID(), text: richText, isUser: false)
        #expect(bubble.structuredResponse != nil)
    }
}
