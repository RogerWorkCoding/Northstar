import SwiftUI
import MapKit

// 🗺️ Places: when Northstar recommends real places, show them on a small Apple Maps card.
// The brain only names them (name + area); the phone finds them. No API key, no location access.
// Tap a row to open it in Apple Maps for directions.

struct PlacesMapCard: View {
    let places: [NorthstarInsight.Place]

    private struct Found: Identifiable {
        let id = UUID()
        let place: NorthstarInsight.Place
        let item: MKMapItem?
    }

    @State private var found: [Found] = []
    @State private var searched = false

    private var pinned: [Found] { found.filter { $0.item != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "map")
                Text("ON THE MAP").tracking(2)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            if !pinned.isEmpty {
                Map(initialPosition: .automatic, interactionModes: []) {
                    ForEach(pinned) { f in
                        if let item = f.item {
                            Marker(f.place.name, coordinate: item.location.coordinate)
                        }
                    }
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            } else if !searched {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 170)
                    .overlay(ProgressView().tint(.white))
            }

            VStack(spacing: 8) {
                ForEach(rows) { f in
                    Button { open(f) } label: { row(f) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .task(id: places) { await search() }
    }

    /// Before the search finishes, show the names so the card isn't empty.
    private var rows: [Found] {
        searched ? found : places.map { Found(place: $0, item: nil) }
    }

    private func row(_ f: Found) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(NorthstarChatStyle.linkBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.place.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .lineLimit(1)
                Text(f.item?.address?.shortAddress ?? f.place.area)
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
        .contentShape(Rectangle())
        .accessibilityLabel("\(f.place.name), \(f.place.area)")
        .accessibilityHint("Opens in Apple Maps")
    }

    /// Finds each place in Apple Maps (one search each, at most 5).
    private func search() async {
        var results: [Found] = []
        for place in places.prefix(5) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "\(place.name), \(place.area)"
            request.resultTypes = [.pointOfInterest, .address]
            let item = try? await MKLocalSearch(request: request).start().mapItems.first
            guard !Task.isCancelled else { return }
            results.append(Found(place: place, item: item))
        }
        found = results
        searched = true
    }

    private func open(_ f: Found) {
        if let item = f.item {
            item.openInMaps()
        } else {
            // Not found on the phone: let Apple Maps search for it.
            var parts = URLComponents(string: "https://maps.apple.com/")!
            parts.queryItems = [URLQueryItem(name: "q", value: "\(f.place.name), \(f.place.area)")]
            if let url = parts.url { UIApplication.shared.open(url) }
        }
    }
}
