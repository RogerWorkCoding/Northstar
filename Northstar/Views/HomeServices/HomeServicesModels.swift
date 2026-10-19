import Foundation
import CoreLocation
import Supabase

// 🔧 Home & Services (Concierge only): the data behind Northstar's one provider recommendation.
// Everything here comes from the northstar-providers function (Google Places today). Nothing is
// invented: no rating, photo, review count or reason exists unless the source returned it.
// Used ONLY by the Home & Services tile. Other Concierge tiles keep their own cards.

/// One photo of the business, with who took it (shown on the photo) and a description for VoiceOver.
nonisolated struct ProviderPhoto: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let url: URL
    /// "Photo by Jane D. on Google"
    let credit: String
    let creditUrl: URL?
    /// Accessibility description.
    let alt: String
}

/// How many people gave each star, ONLY when a source really publishes these counts (Google doesn't).
nonisolated struct RatingDistribution: Hashable, Sendable, Decodable {
    let five: Int, four: Int, three: Int, two: Int, one: Int
    var total: Int { five + four + three + two + one }
    var rows: [(stars: Int, count: Int)] { [(5, five), (4, four), (3, three), (2, two), (1, one)] }
}

/// One place the rating came from, exactly as that source shows it.
nonisolated struct ProviderRatingSource: Hashable, Sendable, Decodable {
    let name: String
    let rating: Double
    let count: Int
    let url: URL?
    let retrieved: String?
    var distribution: RatingDistribution? = nil

    private enum CodingKeys: String, CodingKey { case name, rating, count, url, retrieved, distribution }
}

nonisolated struct HomeServiceProvider: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let name: String
    let category: String
    let address: String
    let miles: Double?
    /// Only when the source has live hours.
    let openNow: Bool?
    let phone: String?
    let website: URL?
    let mapsUrl: URL?
    let photos: [ProviderPhoto]
    let sources: [ProviderRatingSource]
    /// A short, data-backed label for alternatives ("Most reviewed").
    let distinction: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, category, address, miles, openNow, phone, website, mapsUrl, photos, sources, distinction
    }

    init(id: String, name: String, category: String, address: String, miles: Double?, openNow: Bool?,
         phone: String?, website: URL?, mapsUrl: URL?, photos: [ProviderPhoto], sources: [ProviderRatingSource],
         distinction: String?) {
        self.id = id; self.name = name; self.category = category; self.address = address; self.miles = miles
        self.openNow = openNow; self.phone = phone; self.website = website; self.mapsUrl = mapsUrl
        self.photos = photos; self.sources = sources; self.distinction = distinction
    }

    /// Forgiving: one odd photo or link never hides the provider.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = (try? c.decode(String.self, forKey: .category)) ?? ""
        address = (try? c.decode(String.self, forKey: .address)) ?? ""
        miles = try? c.decodeIfPresent(Double.self, forKey: .miles)
        openNow = try? c.decodeIfPresent(Bool.self, forKey: .openNow)
        phone = (try? c.decodeIfPresent(String.self, forKey: .phone))?.flatMap { $0.isEmpty ? nil : $0 }
        website = try? c.decodeIfPresent(URL.self, forKey: .website)
        mapsUrl = try? c.decodeIfPresent(URL.self, forKey: .mapsUrl)
        photos = ((try? c.decode([HSLenient<ProviderPhoto>].self, forKey: .photos)) ?? []).compactMap(\.value)
        sources = ((try? c.decode([HSLenient<ProviderRatingSource>].self, forKey: .sources)) ?? []).compactMap(\.value)
        distinction = try? c.decodeIfPresent(String.self, forKey: .distinction)
    }

    /// Total reviews across sources.
    var reviewCount: Int { sources.reduce(0) { $0 + $1.count } }

    /// Northstar Combined Rating: only with 2+ sources, each weighted by its number of reviews
    /// (so a source with 12 reviews doesn't count as much as one with 400). Nil otherwise.
    var combinedRating: Double? {
        let usable = sources.filter { $0.count > 0 && (0...5).contains($0.rating) }
        guard usable.count >= 2 else { return nil }
        let total = usable.reduce(0) { $0 + $1.count }
        return usable.reduce(0.0) { $0 + $1.rating * Double($1.count) } / Double(total)
    }

    /// Merged star counts, only when EVERY source published them.
    var combinedDistribution: RatingDistribution? {
        let all = sources.compactMap(\.distribution)
        guard !all.isEmpty, all.count == sources.count else { return nil }
        return RatingDistribution(five: all.reduce(0) { $0 + $1.five }, four: all.reduce(0) { $0 + $1.four },
                                  three: all.reduce(0) { $0 + $1.three }, two: all.reduce(0) { $0 + $1.two },
                                  one: all.reduce(0) { $0 + $1.one })
    }
}

nonisolated struct RecommendationReason: Hashable, Sendable, Decodable {
    let text: String
    /// What it's based on ("Google rating and review count").
    let basis: String
}

/// Northstar's one recommendation plus the evidence, what it compared, and what it couldn't check.
nonisolated struct NorthstarProviderRecommendation: Hashable, Sendable, Decodable {
    let status: String
    let retrievedAt: String?
    /// Which ranking method chose it (e.g. "ns-rank-1").
    let methodology: String?
    /// How many providers were compared.
    let compared: Int
    let recommended: HomeServiceProvider?
    let alternatives: [HomeServiceProvider]
    let reasons: [RecommendationReason]
    let limitations: [String]

    private enum CodingKeys: String, CodingKey {
        case status, retrievedAt, methodology, compared, recommended, alternatives, reasons, limitations
    }

    init(status: String, retrievedAt: String?, methodology: String?, compared: Int, recommended: HomeServiceProvider?,
         alternatives: [HomeServiceProvider], reasons: [RecommendationReason], limitations: [String]) {
        self.status = status; self.retrievedAt = retrievedAt; self.methodology = methodology; self.compared = compared
        self.recommended = recommended; self.alternatives = alternatives; self.reasons = reasons; self.limitations = limitations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? c.decode(String.self, forKey: .status)) ?? "error"
        retrievedAt = try? c.decodeIfPresent(String.self, forKey: .retrievedAt)
        methodology = try? c.decodeIfPresent(String.self, forKey: .methodology)
        compared = (try? c.decode(Int.self, forKey: .compared)) ?? 0
        recommended = try? c.decodeIfPresent(HomeServiceProvider.self, forKey: .recommended)
        alternatives = ((try? c.decode([HSLenient<HomeServiceProvider>].self, forKey: .alternatives)) ?? []).compactMap(\.value)
        reasons = (try? c.decode([RecommendationReason].self, forKey: .reasons)) ?? []
        limitations = (try? c.decode([String].self, forKey: .limitations)) ?? []
    }

    var retrievedDate: Date? {
        guard let retrievedAt else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: retrievedAt) ?? ISO8601DateFormatter().date(from: retrievedAt)
    }

    /// Older than a day: say so on the card.
    var isStale: Bool { retrievedDate.map { Date().timeIntervalSince($0) > 86_400 } ?? false }
}

/// Decodes one item, or nil if it can't be read (so one bad item never hides the rest).
nonisolated struct HSLenient<T: Decodable & Sendable>: Decodable, Sendable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// Everything the Home & Services screen can be showing.
enum HomeServicesState: Equatable {
    case loading
    case ready(NorthstarProviderRecommendation)
    case noProviders
    case notSetUp
    case networkError
    case locationUnavailable
    case permissionRequired
}

/// Asks northstar-providers. Only the city's center point is sent, never the person's exact spot.
@MainActor
enum HomeServicesProviderService {
    private nonisolated struct Request: Encodable, Sendable {
        let need: String; let city: String; let lat: Double; let lng: Double
    }

    static func recommend(need: String) async -> HomeServicesState {
        let status = CLLocationManager().authorizationStatus
        if status == .denied || status == .restricted { return .permissionRequired }
        guard let city = await NearMe.shared.cityName() else { return .locationUnavailable }
        guard let center = try? await CLGeocoder().geocodeAddressString(city).first?.location?.coordinate else {
            return .locationUnavailable
        }
        do {
            let reply: NorthstarProviderRecommendation = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-providers",
                options: FunctionInvokeOptions(body: Request(need: need, city: city,
                                                             lat: (center.latitude * 100).rounded() / 100,
                                                             lng: (center.longitude * 100).rounded() / 100))
            )
            switch reply.status {
            case "ok" where reply.recommended != nil: return .ready(reply)
            case "ok", "none": return .noProviders
            case "not_set_up": return .notSetUp
            default: return .networkError
            }
        } catch {
            return .networkError
        }
    }
}
