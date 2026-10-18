import SwiftUI
import MapKit

// 🏠 Apartments (Concierge): up to 3 real listings, each with
//   • a SCAM CHECK on the listing itself (clear · check first · possible scam, with the reasons),
//   • the TRUE monthly cost (rent plus typical extras, estimates labeled),
//   • the COMMUTE to their work or school (Apple Maps, on the phone; the address stays on the phone).
// Fair housing: Northstar never rates neighborhoods or describes who lives there. Listings can be out of date,
// so each card says where it came from and how fresh it is.

struct ApartmentCards: View {
    let listings: [NorthstarInsight.Listing]
    /// "Petaluma, CA", for the Search more links.
    var city: String?

    @AppStorage("ns.commuteTo") private var commuteTo = ""
    @State private var editingCommute = false
    @State private var commuteDraft = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            commuteRow
            ForEach(listings) { l in
                ListingCard(listing: l, commuteTo: commuteTo)
            }
            Label("Never pay a deposit before you've seen the place in person and signed a lease.",
                  systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
            searchMore
        }
    }

    // Where they go every day, so each card can show the real trip.
    @ViewBuilder
    private var commuteRow: some View {
        if editingCommute {
            HStack(spacing: 8) {
                TextField("Work or school address", text: $commuteDraft)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.done)
                    .onSubmit(saveCommute)
                Button("Save", action: saveCommute)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 14)
            .background(Capsule().fill(NorthstarChatStyle.card))
            .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke))
        } else {
            Button {
                commuteDraft = commuteTo
                editingCommute = true
            } label: {
                Label(commuteTo.isEmpty ? "Add work or school to see commute times" : "Commute to: \(commuteTo)",
                      systemImage: "car")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .lineLimit(1)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private func saveCommute() {
        commuteTo = commuteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        editingCommute = false
    }

    // The big sites, already set to their city.
    @ViewBuilder
    private var searchMore: some View {
        if let slug = Self.slug(city) {
            HStack(spacing: 10) {
                Text("Search more:")
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
                link("Zillow", "https://www.zillow.com/\(slug)/rentals/")
                link("Apartments.com", "https://www.apartments.com/\(slug)/")
            }
        }
    }

    private func link(_ title: String, _ address: String) -> some View {
        Button(title) { if let u = URL(string: address) { openURL(u) } }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.linkBlue)
            .frame(minHeight: 44)
    }

    /// "Petaluma, CA" → "petaluma-ca"
    static func slug(_ city: String?) -> String? {
        guard let city, !city.isEmpty else { return nil }
        let s = city.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .split(separator: " ").joined(separator: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return s.isEmpty ? nil : s
    }
}

private struct ListingCard: View {
    let listing: NorthstarInsight.Listing
    let commuteTo: String

    @State private var showCost = false
    @State private var commute: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            scamBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(listing.name)
                    .font(.headline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text([listing.area, listing.sizeText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(NorthstarInsight.Listing.money(listing.rent) + "/mo")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.text)
                if let tc = listing.trueCost, tc.total > listing.rent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showCost.toggle() }
                    } label: {
                        Text("Really about \(NorthstarInsight.Listing.money(tc.total))/mo \(showCost ? "\u{25B4}" : "\u{25BE}")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NorthstarChatStyle.linkBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows what the true monthly cost includes")
                }
            }
            if showCost, let tc = listing.trueCost {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tc.parts, id: \.self) { Text("\u{2022} " + $0) }
                }
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.soft)
            }

            if let commute {
                Label(commute, systemImage: "car")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.text)
            }
            if let why = listing.why, !why.isEmpty {
                Text(why)
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(([listing.source.map { "From \($0)" }, listing.posted].compactMap { $0 }.filter { !$0.isEmpty } + ["can change"])
                .joined(separator: " \u{00B7} "))
                .font(.caption)
                .foregroundStyle(NorthstarChatStyle.label)

            HStack(spacing: 10) {
                Button { openURL(listing.url) } label: {
                    Label("View listing", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                }
                .buttonStyle(.plain)
                if let area = listing.area, !area.isEmpty {
                    Button { directions(to: area) } label: {
                        Label("Directions", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(borderColor, lineWidth: listing.scam.level == "warning" ? 1.5 : 1))
        .task(id: commuteTo) { commute = await Self.commuteText(from: listing.area, to: commuteTo) }
    }

    // MARK: Scam check

    private var scamBadge: some View {
        let (icon, title, color): (String, String, Color) = switch listing.scam.level {
        case "clear": ("checkmark.shield", "Scam check: no warning signs found", NorthstarChatStyle.savedGreen)
        case "warning": ("exclamationmark.octagon", "Scam check: possible scam", Color(red: 1.0, green: 0.45, blue: 0.40))
        default: ("exclamationmark.triangle", "Scam check: check before you pay", NorthstarChatStyle.warning)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            ForEach(listing.scam.reasons, id: \.self) { reason in
                Text("\u{2022} " + reason)
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }

    private var borderColor: Color {
        listing.scam.level == "warning" ? Color(red: 1.0, green: 0.45, blue: 0.40).opacity(0.7) : NorthstarChatStyle.stroke
    }

    // MARK: Commute and directions

    private func directions(to place: String) {
        var parts = URLComponents(string: "https://maps.apple.com/")!
        parts.queryItems = [URLQueryItem(name: "daddr", value: place)]
        if let url = parts.url { openURL(url) }
    }

    /// "22 min drive to work" from the listing's area to their saved address (Apple Maps, on the phone).
    static func commuteText(from place: String?, to destination: String) async -> String? {
        guard let place, !place.isEmpty, !destination.isEmpty else { return nil }
        let geocoder = CLGeocoder()
        guard let a = try? await geocoder.geocodeAddressString(place).first?.location,
              let b = try? await CLGeocoder().geocodeAddressString(destination).first?.location else { return nil }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: a.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: b.coordinate))
        request.transportType = .automobile
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return nil }
        let minutes = max(1, Int((eta.expectedTravelTime / 60).rounded()))
        return "About \(minutes) min drive to work or school"
    }
}
