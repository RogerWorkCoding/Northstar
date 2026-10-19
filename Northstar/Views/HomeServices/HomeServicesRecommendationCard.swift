import SwiftUI

// 🔧 Home & Services: Northstar's one recommended provider, as a photo card.
//   Photos (credited) → ✦ Northstar Recommends → who they are → why → rating → sources → trust line → actions.
// Only shows what the data has. Missing photos, hours, star breakdowns or a second source are left out
// or said plainly; nothing is filled in. Northstar never contacts, books or pays from here.

struct HomeServicesRecommendationCard: View {
    let recommendation: NorthstarProviderRecommendation
    let provider: HomeServiceProvider
    var onCompare: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProviderPhotoGallery(photos: provider.photos, providerName: provider.name)

            VStack(alignment: .leading, spacing: 18) {
                NorthstarRecommendationBadge()
                ProviderIdentity(provider: provider)
                Text(statement)
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                CombinedRatingSummary(provider: provider)
                if let d = provider.combinedDistribution { RatingDistributionView(distribution: d) }
                if !recommendation.reasons.isEmpty { RecommendationReasonsView(reasons: recommendation.reasons) }
                ReviewSourcesView(sources: provider.sources, stale: recommendation.isStale)
                Label("Northstar never contacts, books, or pays without your approval.", systemImage: "hand.raised")
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
                HomeServicesProviderActions(provider: provider, onCompare: recommendation.alternatives.isEmpty ? nil : onCompare)
            }
            .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(NorthstarChatStyle.card))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }

    /// Says only what was really compared.
    private var statement: String {
        let n = provider.sources.count
        if n >= 2 {
            return "After comparing the ratings and number of reviews across \(n) sources, I recommend this provider. You make the final call."
        }
        let k = recommendation.compared
        let source = provider.sources.first?.name ?? "one source"
        if k > 1 {
            return "I compared \(k) local providers by their \(source) rating and how many people reviewed them. This is the one I recommend. My view is based on one source, so check them out before you hire. You make the final call."
        }
        return "This was the only provider with enough \(source) reviews to judge. My view is limited, so check them out before you hire."
    }
}

// MARK: Photos

struct ProviderPhotoGallery: View {
    let photos: [ProviderPhoto]
    let providerName: String
    @State private var page = 0

    var body: some View {
        Group {
            if photos.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(NorthstarChatStyle.label)
                    Text("No verified business photos available.")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(NorthstarChatStyle.cardStrong)
                .accessibilityElement(children: .combine)
            } else {
                TabView(selection: $page) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { i, photo in
                        ProviderPhotoView(photo: photo).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
                .frame(height: 230)
                .accessibilityLabel("Photos of \(providerName), \(photos.count) \(photos.count == 1 ? "photo" : "photos")")
            }
        }
    }
}

private struct ProviderPhotoView: View {
    let photo: ProviderPhoto
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: photo.url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.title2)
                        Text("This photo couldn't load.").font(.footnote)
                    }
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NorthstarChatStyle.cardStrong)
                default:
                    ProgressView()
                        .tint(NorthstarChatStyle.text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(NorthstarChatStyle.cardStrong)
                        .accessibilityLabel("Loading photo")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .accessibilityLabel(photo.alt)

            // Who took it, on a dark band so it's always readable.
            Button {
                if let u = photo.creditUrl { openURL(u) }
            } label: {
                Text(photo.credit)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .disabled(photo.creditUrl == nil)
            .padding(10)
            .padding(.bottom, 18) // clear of the page dots
            .accessibilityLabel(photo.credit)
        }
    }
}

// MARK: Badge and identity

struct NorthstarRecommendationBadge: View {
    var body: some View {
        Label {
            Text("Northstar Recommends")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
        } icon: {
            Image(systemName: "sparkle")
        }
        .foregroundStyle(HomeServicesStyle.gold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(HomeServicesStyle.gold.opacity(0.14)))
        .overlay(Capsule().strokeBorder(HomeServicesStyle.gold.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct ProviderIdentity: View {
    let provider: HomeServiceProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(provider.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text([provider.category, provider.address].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let miles = provider.miles {
                    Label(String(format: miles < 10 ? "%.1f mi from the city center" : "%.0f mi from the city center", miles),
                          systemImage: "location")
                }
                if let open = provider.openNow {
                    Text(open ? "Open now" : "Closed now")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(open ? NorthstarChatStyle.savedGreen : NorthstarChatStyle.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill((open ? NorthstarChatStyle.savedGreen : NorthstarChatStyle.warning).opacity(0.14)))
                }
            }
            .font(.footnote)
            .foregroundStyle(NorthstarChatStyle.label)
        }
    }
}

// MARK: Ratings

struct CombinedRatingSummary: View {
    let provider: HomeServiceProvider

    var body: some View {
        if let combined = provider.combinedRating {
            box(title: "Northstar Combined Rating", value: combined,
                detail: "Based on \(provider.reviewCount.formatted()) reviews across \(provider.sources.count) sources, weighted by how many reviews each has",
                spoken: "Northstar combined rating \(Self.one(combined)) out of 5, based on \(provider.reviewCount) reviews across \(provider.sources.count) sources")
        } else if let s = provider.sources.first {
            box(title: "\(s.name) rating", value: s.rating,
                detail: "From \(s.count.formatted()) reviews on \(s.name)",
                spoken: "\(s.name) rating \(Self.one(s.rating)) out of 5, based on \(s.count) reviews")
        }
    }

    private func box(title: String, value: Double, detail: String, spoken: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(NorthstarChatStyle.label)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Self.one(value))
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(NorthstarChatStyle.text)
                Text("out of 5")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.soft)
                Spacer(minLength: 0)
                StarsView(rating: value)
            }
            Text(detail)
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.cardStrong))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    static func one(_ v: Double) -> String { String(format: "%.1f", v) }
}

private struct StarsView: View {
    let rating: Double
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: rating >= Double(i) - 0.25 ? "star.fill" : (rating >= Double(i) - 0.75 ? "star.leadinghalf.filled" : "star"))
            }
        }
        .font(.caption)
        .foregroundStyle(HomeServicesStyle.gold)
        .accessibilityHidden(true)
    }
}

/// Real star counts only (shown when every source publishes them; Google doesn't, so this is usually hidden).
struct RatingDistributionView: View {
    let distribution: RatingDistribution

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(distribution.rows, id: \.stars) { row in
                HStack(spacing: 10) {
                    Text("\(row.stars) \(row.stars == 1 ? "star" : "stars")")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.soft)
                        .frame(width: 58, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NorthstarChatStyle.cardStrong)
                            Capsule().fill(HomeServicesStyle.gold)
                                .frame(width: distribution.total > 0 ? geo.size.width * CGFloat(row.count) / CGFloat(distribution.total) : 0)
                        }
                    }
                    .frame(height: 8)
                    Text(row.count.formatted())
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(NorthstarChatStyle.text)
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.stars) stars: \(row.count) reviews")
            }
        }
    }
}

// MARK: Why, and sources

struct RecommendationReasonsView: View {
    let reasons: [RecommendationReason]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why I recommend them")
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.text)
                .accessibilityAddTraits(.isHeader)
            ForEach(reasons, id: \.self) { r in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(HomeServicesStyle.gold)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.text)
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Based on: \(r.basis)")
                            .font(.caption)
                            .foregroundStyle(NorthstarChatStyle.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct ReviewSourcesView: View {
    let sources: [ProviderRatingSource]
    var stale = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources reviewed")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(NorthstarChatStyle.label)
            ForEach(sources, id: \.self) { s in
                Button {
                    if let u = s.url { openURL(u) }
                } label: {
                    HStack(spacing: 8) {
                        Text(s.name).font(.subheadline.weight(.semibold))
                        Text("\(CombinedRatingSummary.one(s.rating)) \u{00B7} \(s.count.formatted()) reviews")
                            .font(.subheadline)
                        if let when = Self.when(s.retrieved) {
                            Text("\u{00B7} checked \(when)").font(.caption)
                        }
                        if s.url != nil { Image(systemName: "arrow.up.right").font(.caption) }
                    }
                    .foregroundStyle(NorthstarChatStyle.text)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(NorthstarChatStyle.cardStrong))
                    .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(s.url == nil)
                .accessibilityLabel("\(s.name): \(CombinedRatingSummary.one(s.rating)) out of 5 based on \(s.count) reviews")
                .accessibilityHint(s.url == nil ? "" : "Opens \(s.name)")
            }
            if stale {
                Label("This information is more than a day old.", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(NorthstarChatStyle.warning)
            }
        }
    }

    static func when(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        return Calendar.current.isDateInToday(d) ? d.formatted(date: .omitted, time: .shortened)
                                                 : d.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: Actions (nothing happens without a tap)

struct HomeServicesProviderActions: View {
    let provider: HomeServiceProvider
    var onCompare: (() -> Void)?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 10) {
            if let primary = provider.mapsUrl ?? provider.website {
                Button { openURL(primary) } label: {
                    Text("View provider")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                }
                .buttonStyle(.plain)
            }
            // Secondary actions, only with real details behind them.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { secondary }
                VStack(spacing: 8) { secondary }
            }
        }
    }

    @ViewBuilder
    private var secondary: some View {
        if let phone = provider.phone, let tel = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
            small("Call", "phone") { openURL(tel) }
        }
        if let site = provider.website {
            small("Website", "safari") { openURL(site) }
        }
        if !provider.address.isEmpty {
            small("Directions", "map") {
                var parts = URLComponents(string: "https://maps.apple.com/")!
                parts.queryItems = [URLQueryItem(name: "daddr", value: "\(provider.name), \(provider.address)")]
                if let u = parts.url { openURL(u) }
            }
        }
        if let onCompare {
            small("Compare options", "square.grid.2x2", action: onCompare)
        }
    }

    private func small(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Compare options

struct AlternativeProviderCard: View {
    let provider: HomeServiceProvider
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let photo = provider.photos.first {
                    AsyncImage(url: photo.url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { NorthstarChatStyle.cardStrong }
                    }
                    .accessibilityLabel(photo.alt)
                } else {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.title3)
                        .foregroundStyle(NorthstarChatStyle.label)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(NorthstarChatStyle.cardStrong)
                        .accessibilityLabel("No verified photo")
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.headline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let s = provider.sources.first {
                    Text("\(CombinedRatingSummary.one(provider.combinedRating ?? s.rating)) out of 5 \u{00B7} \(provider.reviewCount.formatted()) \(provider.sources.count > 1 ? "reviews" : "\(s.name) reviews")")
                        .font(.subheadline)
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
                if let d = provider.distinction {
                    Text(d)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(NorthstarChatStyle.cardStrong))
                }
                if let u = provider.mapsUrl ?? provider.website {
                    Button("View provider") { openURL(u) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .frame(minHeight: 44)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }
}

/// Home & Services colors (kept here, not global).
enum HomeServicesStyle {
    /// Northstar's warm gold, used sparingly for the recommendation.
    /// Bright on navy, deeper on the light theme so it stays readable.
    static let gold = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.91, green: 0.72, blue: 0.36, alpha: 1)
        : UIColor(red: 0.55, green: 0.38, blue: 0.08, alpha: 1) })
}
