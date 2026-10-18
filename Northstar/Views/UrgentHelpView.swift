import SwiftUI
import MapKit

// 🆘 Urgent Help (Concierge): real help, fast. No AI and no waiting on the brain.
// 911 is always on top. Below it: the nearest emergency room, urgent care, 24-hour pharmacy and
// emergency vet (from Apple Maps, with distance, Call and Go), then hotlines that work anywhere in the US.
// Northstar never says what might be wrong; if it could be serious, call 911.

struct UrgentHelpView: View {
    static let red = Color(red: 0.80, green: 0.18, blue: 0.16)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    struct Kind: Identifiable {
        let id: String
        let title: String
        let icon: String
        let query: String
        let filter: [MKPointOfInterestCategory]
    }

    struct Found: Identifiable {
        let id = UUID()
        let item: MKMapItem
        let miles: Double?
    }

    private let kinds: [Kind] = [
        .init(id: "er", title: "Emergency room", icon: "cross.fill", query: "hospital emergency room", filter: [.hospital]),
        .init(id: "urgent", title: "Urgent care", icon: "stethoscope", query: "urgent care", filter: []),
        .init(id: "pharmacy", title: "24-hour pharmacy", icon: "pills.fill", query: "24 hour pharmacy", filter: [.pharmacy]),
        .init(id: "vet", title: "Emergency vet", icon: "pawprint.fill", query: "emergency veterinarian", filter: []),
    ]

    @State private var results: [String: [Found]] = [:]
    @State private var loading = true
    @State private var noLocation = false

    var body: some View {
        NavigationStack {
            ZStack {
                NorthstarChatStyle.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        call911
                        Text("Northstar can't tell you what's wrong. If it might be serious, call 911.")
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.soft)
                            .fixedSize(horizontal: false, vertical: true)

                        sectionTitle("NEAREST TO YOU")
                        if noLocation {
                            Text("Turn on Location for Northstar in iPhone Settings to see the closest places.")
                                .font(.subheadline)
                                .foregroundStyle(NorthstarChatStyle.soft)
                        }
                        ForEach(kinds) { kind in
                            placeRow(kind)
                        }
                        Text("Hours can change. Call ahead if you can.")
                            .font(.footnote)
                            .foregroundStyle(NorthstarChatStyle.label)

                        sectionTitle("HELP LINES (FREE, 24/7)")
                        hotline("Poison Control", detail: "Swallowed something, or a chemical in the eyes or on skin",
                                icon: "exclamationmark.triangle.fill", number: "18002221222", shown: "1-800-222-1222")
                        hotline("988 Lifeline", detail: "Call or text if you or someone is in crisis",
                                icon: "heart.fill", number: "988", shown: "988", text: true)
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Urgent Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await searchAll() }
    }

    // MARK: Pieces

    private var call911: some View {
        Button { if let url = URL(string: "tel:911") { openURL(url) } } label: {
            HStack(spacing: 14) {
                Image(systemName: "phone.fill").font(.system(size: 26, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Call 911").font(.system(size: 26, weight: .bold))
                    Text("Emergency: police, fire, ambulance").font(.subheadline).opacity(0.9)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Self.red))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call 911")
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.caption.weight(.semibold))
            .tracking(2)
            .foregroundStyle(NorthstarChatStyle.label)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func placeRow(_ kind: Kind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind.title, systemImage: kind.icon)
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.text)
            if let list = results[kind.id], !list.isEmpty {
                ForEach(list) { f in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(f.item.name ?? kind.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(NorthstarChatStyle.text)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            if let miles = f.miles {
                                Text(String(format: miles < 10 ? "%.1f mi" : "%.0f mi", miles))
                                    .font(.footnote)
                                    .foregroundStyle(NorthstarChatStyle.label)
                            }
                        }
                        if let address = f.item.address?.shortAddress {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(NorthstarChatStyle.soft)
                                .lineLimit(2)
                        }
                        HStack(spacing: 8) {
                            if let phone = f.item.phoneNumber,
                               let url = URL(string: "tel:" + phone.filter { "0123456789+".contains($0) }) {
                                pill("Call", icon: "phone.fill", primary: true) { openURL(url) }
                            }
                            pill("Go", icon: "car.fill", primary: false) {
                                f.item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } else if loading {
                ProgressView().tint(NorthstarChatStyle.text)
            } else {
                Text("None found nearby.")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.soft)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func hotline(_ title: String, detail: String, icon: String, number: String, shown: String, text: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.text)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                pill("Call \(shown)", icon: "phone.fill", primary: true) {
                    if let url = URL(string: "tel:\(number)") { openURL(url) }
                }
                if text {
                    pill("Text", icon: "message.fill", primary: false) {
                        if let url = URL(string: "sms:\(number)") { openURL(url) }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }

    private func pill(_ title: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary ? NorthstarChatStyle.onPrimary : NorthstarChatStyle.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(primary ? NorthstarChatStyle.primaryFill : Color.clear))
                .overlay(Capsule().strokeBorder(primary ? Color.clear : NorthstarChatStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Apple Maps search, nearest first (2 per kind)

    private func searchAll() async {
        let here = await NearMe.shared.currentLocation()
        noLocation = here == nil
        for kind in kinds {
            results[kind.id] = await Self.search(kind, near: here)
        }
        loading = false
    }

    private static func search(_ kind: Kind, near here: CLLocation?) async -> [Found] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = kind.query
        request.resultTypes = .pointOfInterest
        if !kind.filter.isEmpty { request.pointOfInterestFilter = MKPointOfInterestFilter(including: kind.filter) }
        if let here {
            request.region = MKCoordinateRegion(center: here.coordinate, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        }
        let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        let found = items.map { item in
            Found(item: item, miles: here.map { item.location.distance(from: $0) / 1609.34 })
        }
        return Array(found.sorted { ($0.miles ?? .infinity) < ($1.miles ?? .infinity) }.prefix(2))
    }
}

#Preview {
    UrgentHelpView()
}
