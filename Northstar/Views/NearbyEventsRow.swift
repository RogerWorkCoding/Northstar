import SwiftUI
import CoreLocation
import Supabase

// 🎟 "Happening near you" (Concierge): event images to swipe through, below the tiles.
// Only the CITY's center point is sent (never the person's exact spot). Events come from Ticketmaster
// and SeatGeek through the northstar-nearby function. Tap a card for Tickets, Directions and Add to calendar.
// If there's nothing to show (no location, not set up, no events), the row simply isn't there.

nonisolated struct NearbyEvent: Identifiable, Hashable, Sendable, Decodable {
    var id: String { url.absoluteString }
    let name: String
    let date: String      // YYYY-MM-DD
    let time: String?     // HH:MM
    let venue: String
    let city: String
    let image: URL
    let url: URL
    let miles: Double?
    /// Where it came from: "Ticketmaster" or "SeatGeek" (for the credit line).
    var source: String? = nil

    var start: Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(date) \(time ?? "12:00")")
    }

    /// "Sat 7:30 PM", "Today 8 PM", "Oct 30".
    var whenText: String {
        guard let start else { return date }
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(start) { day = "Today" }
        else if cal.isDateInTomorrow(start) { day = "Tomorrow" }
        else if let d = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: start).day, d < 7 {
            day = start.formatted(.dateTime.weekday(.abbreviated))
        } else {
            day = start.formatted(.dateTime.month(.abbreviated).day())
        }
        guard time != nil else { return day }
        return "\(day) \(start.formatted(date: .omitted, time: .shortened))"
    }
}

@MainActor
enum NearbyEvents {
    private nonisolated struct Request: Encodable, Sendable { let lat: Double; let lng: Double }
    private nonisolated struct Reply: Decodable, Sendable { let events: [NearbyEvent]? }
    private static var cached: (city: String, at: Date, events: [NearbyEvent])?

    static func load() async -> [NearbyEvent] {
        guard let city = await NearMe.shared.cityName() else { return [] }
        if let c = cached, c.city == city, Date().timeIntervalSince(c.at) < 1800 { return c.events }
        // The city's center, not where the person is standing.
        guard let center = try? await CLGeocoder().geocodeAddressString(city).first?.location?.coordinate else { return [] }
        do {
            let reply: Reply = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-nearby",
                options: FunctionInvokeOptions(body: Request(lat: (center.latitude * 100).rounded() / 100,
                                                             lng: (center.longitude * 100).rounded() / 100))
            )
            let events = reply.events ?? []
            // Remember only a real list, so an empty answer can be tried again soon.
            if !events.isEmpty { cached = (city, Date(), events) }
            return events
        } catch {
            return []
        }
    }
}

struct NearbyEventsRow: View {
    @State private var events: [NearbyEvent] = []
    @State private var open: NearbyEvent?

    var body: some View {
        Group {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("HAPPENING NEAR YOU")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(NorthstarChatStyle.label)
                        .accessibilityAddTraits(.isHeader)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(events) { e in
                                Button { open = e } label: { card(e) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                    Text("Events from " + Set(events.compactMap(\.source)).sorted().joined(separator: " and "))
                        .font(.caption2)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
                .padding(.top, 8)
            }
        }
        .task { events = await NearbyEvents.load() }
        .sheet(item: $open) { e in
            NearbyEventSheet(event: e)
                .presentationDetents([.medium, .large])
        }
    }

    private func card(_ e: NearbyEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: e.image) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    NorthstarChatStyle.card
                }
            }
            .frame(width: 220, height: 124)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(e.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .lineLimit(2, reservesSpace: true)
                Text([e.whenText, e.miles.map { String(format: $0 < 10 ? "%.1f mi" : "%.0f mi", $0) }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(width: 220, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows tickets, directions and add to calendar")
    }
}

/// The Events tile: every event nearby, as big image cards, soonest first.
struct NearbyEventsList: View {
    @State private var events: [NearbyEvent] = []
    @State private var loading = true
    @State private var open: NearbyEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Happening near you")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(NorthstarChatStyle.text)
                .accessibilityAddTraits(.isHeader)

            if loading {
                HStack(spacing: 10) {
                    ProgressView().tint(NorthstarChatStyle.text)
                    Text("Finding events near you…").foregroundStyle(NorthstarChatStyle.soft)
                }
                .padding(.vertical, 8)
            } else if events.isEmpty {
                Text("I couldn't find events near you right now. If Location is off for Northstar, turn it on in iPhone Settings, then try again.")
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await load() } }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .frame(minHeight: 44)
            } else {
                ForEach(events) { e in
                    Button { open = e } label: { card(e) }
                        .buttonStyle(.plain)
                }
                Text("Events from " + Set(events.compactMap(\.source)).sorted().joined(separator: " and "))
                    .font(.caption2)
                    .foregroundStyle(NorthstarChatStyle.label)
            }
        }
        .task { await load() }
        .sheet(item: $open) { e in
            NearbyEventSheet(event: e)
                .presentationDetents([.medium, .large])
        }
    }

    private func load() async {
        loading = true
        events = await NearbyEvents.load()
        loading = false
    }

    private func card(_ e: NearbyEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: e.image) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { NorthstarChatStyle.card }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(e.name)
                    .font(.headline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text([e.whenText, [e.venue, e.city].filter { !$0.isEmpty }.joined(separator: ", "),
                      e.miles.map { String(format: $0 < 10 ? "%.1f mi" : "%.0f mi", $0) }]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows tickets, directions and add to calendar")
    }
}

private struct NearbyEventSheet: View {
    let event: NearbyEvent
    @Environment(\.openURL) private var openURL
    @State private var saved: String?

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncImage(url: event.image) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { NorthstarChatStyle.card }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.name)
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(event.whenText, systemImage: "calendar")
                        Label([event.venue, event.city].filter { !$0.isEmpty }.joined(separator: ", "), systemImage: "mappin.and.ellipse")
                    }
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.soft)

                    button("Tickets", icon: "ticket", primary: true) { openURL(event.url) }
                    HStack(spacing: 10) {
                        button("Directions", icon: "car", primary: false) { directions() }
                        button(saved ?? "Add to calendar", icon: saved == nil ? "calendar.badge.plus" : "checkmark", primary: false) { add() }
                            .disabled(saved != nil)
                    }
                }
                .padding(20)
            }
        }
    }

    private func button(_ title: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary ? NorthstarChatStyle.onPrimary : NorthstarChatStyle.text)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Capsule().fill(primary ? NorthstarChatStyle.primaryFill : Color.clear))
                .overlay(Capsule().strokeBorder(primary ? Color.clear : NorthstarChatStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func directions() {
        var parts = URLComponents(string: "https://maps.apple.com/")!
        parts.queryItems = [URLQueryItem(name: "daddr", value: [event.venue, event.city].filter { !$0.isEmpty }.joined(separator: ", "))]
        if let url = parts.url { openURL(url) }
    }

    private func add() {
        let item = NorthstarInsight.Schedule(kind: "event", title: event.name, date: event.date, time: event.time ?? "12:00",
                                             minutes: 120, alertMinutes: 120,
                                             location: [event.venue, event.city].filter { !$0.isEmpty }.joined(separator: ", "),
                                             repeatRule: nil)
        Task {
            do { saved = "Added to \(try await NorthstarCalendar.shared.add(item))" }
            catch { saved = nil }
        }
    }
}
