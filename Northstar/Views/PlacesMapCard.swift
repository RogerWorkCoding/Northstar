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
    /// For one place (like a city), frame the whole area instead of zooming in on a pin.
    @State private var area: MKCoordinateRegion?

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
                Map(initialPosition: area.map { .region($0) } ?? .automatic, interactionModes: []) {
                    ForEach(pinned) { f in
                        if let item = f.item {
                            Marker(f.place.name, coordinate: item.location.coordinate)
                        }
                    }
                }
                .id(area?.center.latitude)  // redraw once the area is known
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Label("Open in Maps", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(8)
                }
                .contentShape(Rectangle())
                .onTapGesture { openAll() }
                .accessibilityElement()
                .accessibilityLabel("Map of \(pinned.map(\.place.name).joined(separator: ", "))")
                .accessibilityHint("Opens in Apple Maps")
                .accessibilityAddTraits(.isButton)
            } else if !searched {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 220)
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
        var firstRegion: MKCoordinateRegion?
        for place in places.prefix(5) {
            let request = MKLocalSearch.Request()
            // A city's own name is its area ("Petaluma" in "Petaluma, CA"): search once, not twice.
            let sameName = place.area.lowercased().hasPrefix(place.name.lowercased())
            request.naturalLanguageQuery = sameName ? place.area : "\(place.name), \(place.area)"
            request.resultTypes = [.pointOfInterest, .address, .physicalFeature]
            let response = try? await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            if firstRegion == nil { firstRegion = response?.boundingRegion }
            results.append(Found(place: place, item: response?.mapItems.first))
        }
        found = results
        // One place: show its whole area (a city fills the map). Several: fit all the pins.
        if results.filter({ $0.item != nil }).count == 1, let region = firstRegion {
            area = region
        }
        searched = true
    }

    /// Tap the map: open every pin in Apple Maps.
    private func openAll() {
        let items = pinned.compactMap(\.item)
        if items.count == 1 { items[0].openInMaps() } else if !items.isEmpty { _ = MKMapItem.openMaps(with: items) }
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
