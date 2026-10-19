import SwiftUI

// 🔧 Home & Services results: one recommendation card, "Compare options" for 2–4 others, and what
// Northstar couldn't check. Every state has words, never a blank space.

struct HomeServicesResultsView: View {
    let need: String
    let state: HomeServicesState
    var onRetry: () -> Void

    @State private var comparing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .loading:
                loadingCard
            case .ready(let rec):
                if let provider = rec.recommended {
                    HomeServicesRecommendationCard(recommendation: rec, provider: provider) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { comparing.toggle() }
                    }
                    if comparing, !rec.alternatives.isEmpty {
                        compare(rec)
                    }
                    limitations(rec)
                }
            case .noProviders:
                message("magnifyingglass",
                        "I couldn't find providers with enough reviews for \u{201C}\(need)\u{201D} near you.",
                        "Try a different word, like \u{201C}drain cleaning\u{201D} or \u{201C}house cleaning\u{201D}.", retry: false)
            case .notSetUp:
                message("wrench.and.screwdriver",
                        "Provider recommendations aren't switched on yet.",
                        "They'll appear here once Northstar's provider search is set up.", retry: false)
            case .networkError:
                message("wifi.exclamationmark",
                        "I couldn't reach the provider search.",
                        "Check your connection, then try again.", retry: true)
            case .locationUnavailable:
                message("location.slash",
                        "I couldn't tell which city you're in.",
                        "Make sure Location is on, then try again. Only your city is used, never your exact spot.", retry: true)
            case .permissionRequired:
                message("location.slash",
                        "Northstar needs your city to find local providers.",
                        "Turn on Location for Northstar in iPhone Settings \u{203A} Privacy & Security \u{203A} Location Services. Only your city is used.", retry: true)
            }
        }
        .onChange(of: state) { comparing = false }
    }

    private var loadingCard: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NorthstarChatStyle.cardStrong)
                .frame(height: 180)
            HStack(spacing: 10) {
                ProgressView().tint(NorthstarChatStyle.text)
                Text("Comparing local providers for \u{201C}\(need)\u{201D}\u{2026}")
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func compare(_ rec: NorthstarProviderRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other options")
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.text)
                .accessibilityAddTraits(.isHeader)
            Text("I still recommend the one above. These were next by the same method.")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(rec.alternatives) { AlternativeProviderCard(provider: $0) }
        }
        .transition(.opacity)
    }

    private func limitations(_ rec: NorthstarProviderRecommendation) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rec.limitations, id: \.self) { Text("\u{2022} " + $0) }
                Text("\u{2022} Ranked by rating weighed by number of reviews (\(rec.methodology ?? "Northstar method")). No paid placement.")
            }
            .font(.footnote)
            .foregroundStyle(NorthstarChatStyle.soft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("What I couldn't check")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)
        }
        .tint(NorthstarChatStyle.text)
        .frame(minHeight: 44)
    }

    private func message(_ icon: String, _ title: String, _ detail: String, retry: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(NorthstarChatStyle.label)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
            if retry {
                Button("Try again", action: onRetry)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .frame(minHeight: 44)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }
}

// MARK: Development previews only (SAMPLE data, clearly labeled; never in the app people use)

#if DEBUG
enum HomeServicesSamples {
    static let sampleNote = "SAMPLE"

    static func provider(_ name: String, photos: Int, sources: [ProviderRatingSource], distinction: String? = nil) -> HomeServiceProvider {
        HomeServiceProvider(
            id: name, name: "\(name) (\(sampleNote))", category: "Plumber", address: "Sample St, Sampletown",
            miles: 2.4, openNow: true, phone: "5555550100", website: URL(string: "https://example.com"),
            mapsUrl: URL(string: "https://example.com"),
            photos: (0..<photos).map { i in
                ProviderPhoto(id: "\(name)-\(i)", url: URL(string: "https://example.com/sample-\(i).jpg")!,
                              credit: "SAMPLE photo credit", creditUrl: nil, alt: "Sample photo \(i + 1)")
            },
            sources: sources, distinction: distinction)
    }

    static let google = ProviderRatingSource(name: "Google", rating: 4.8, count: 312, url: nil, retrieved: nil)

    static func recommendation(photos: Int = 3, twoSources: Bool = false) -> NorthstarProviderRecommendation {
        var sources = [google]
        if twoSources {
            sources.append(ProviderRatingSource(name: "Sample Source", rating: 4.6, count: 125, url: nil, retrieved: nil,
                                                distribution: RatingDistribution(five: 90, four: 20, three: 8, two: 4, one: 3)))
            sources[0].distribution = RatingDistribution(five: 262, four: 41, three: 6, two: 2, one: 1)
        }
        return NorthstarProviderRecommendation(
            status: "ok", retrievedAt: nil, methodology: "ns-rank-1", compared: 6,
            recommended: provider("Sample Plumbing Co.", photos: photos, sources: sources),
            alternatives: [provider("Sample Drain Pros", photos: 1, sources: [google], distinction: "Most reviewed"),
                           provider("Sample Pipe Works", photos: 0, sources: [google])],
            reasons: [RecommendationReason(text: "SAMPLE reason: rated 4.8 out of 5 from 312 reviews.", basis: "Sample data")],
            limitations: ["SAMPLE limitation: one source only."])
    }
}

#Preview("Complete") {
    ScrollView { HomeServicesResultsView(need: "Plumber", state: .ready(HomeServicesSamples.recommendation(twoSources: true)), onRetry: {}).padding() }
}
#Preview("Partial: one source, no photo") {
    ScrollView { HomeServicesResultsView(need: "Plumber", state: .ready(HomeServicesSamples.recommendation(photos: 0)), onRetry: {}).padding() }
}
#Preview("Loading") {
    HomeServicesResultsView(need: "Plumber", state: .loading, onRetry: {}).padding()
}
#Preview("Error") {
    HomeServicesResultsView(need: "Plumber", state: .networkError, onRetry: {}).padding()
}
#endif
