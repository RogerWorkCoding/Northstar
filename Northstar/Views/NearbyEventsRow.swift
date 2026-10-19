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

    private enum CodingKeys: String, CodingKey { case name, date, time, venue, city, image, url, miles, source }

    /// Forgiving: links with odd characters are cleaned up, and missing words become empty,
    /// so one unusual event from Ticketmaster or SeatGeek never hides the whole row.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func link(_ key: CodingKeys) throws -> URL {
            let raw = try c.decode(String.self, forKey: key).trimmingCharacters(in: .whitespacesAndNewlines)
            if let u = URL(string: raw), u.scheme == "https" { return u }
            if let fixed = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed.union(.urlQueryAllowed)),
               let u = URL(string: fixed), u.scheme == "https" { return u }
            throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Not a usable link")
        }
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        date = try c.decode(String.self, forKey: .date)
        time = try? c.decodeIfPresent(String.self, forKey: .time)
        venue = (try? c.decodeIfPresent(String.self, forKey: .venue)) ?? ""
        city = (try? c.decodeIfPresent(String.self, forKey: .city)) ?? ""
        image = try link(.image)
        url = try link(.url)
        miles = try? c.decodeIfPresent(Double.self, forKey: .miles)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
    }

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
    /// One event that can't be read is skipped, never the whole list.
    private nonisolated struct Lenient: Decodable, Sendable {
        let event: NearbyEvent?
        init(from decoder: Decoder) throws { event = try? NearbyEvent(from: decoder) }
    }
    private nonisolated struct Reply: Decodable, Sendable { let events: [Lenient]? }
    private static var cached: (city: String, at: Date, events: [NearbyEvent])?

    /// Events near the person's own city, or in `chosenCity` when they picked another one ("Austin, TX").
    static func load(chosenCity: String? = nil) async -> [NearbyEvent] {
        let picked = chosenCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let found: String? = picked.isEmpty ? await NearMe.shared.cityName() : picked
        guard let city = found else { return [] }
        if let c = cached, c.city == city, Date().timeIntervalSince(c.at) < 1800 { return c.events }
        // The city's center, not where the person is standing.
        guard let center = try? await CLGeocoder().geocodeAddressString(city).first?.location?.coordinate else { return [] }
        do {
            let reply: Reply = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-nearby",
                options: FunctionInvokeOptions(body: Request(lat: (center.latitude * 100).rounded() / 100,
                                                             lng: (center.longitude * 100).rounded() / 100))
            )
            let events = (reply.events ?? []).compactMap(\.event).filter { !$0.name.isEmpty }
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

    @State private var finished = false
    /// Opens the Events list (the static images use it).
    var onBrowse: (() -> Void)? = nil

    init(onBrowse: (() -> Void)? = nil) { self.onBrowse = onBrowse }

    private static let categories: [(title: String, image: String)] = [
        ("Music", "EventCard-music"), ("Sports", "EventCard-sports"),
        ("Theater", "EventCard-theater"), ("Comedy", "EventCard-comedy"),
    ]

    private func categoryCard(_ c: (title: String, image: String)) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(c.image)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 120)
                .clipped()
            Text(c.title)
                .font(.headline)
                .foregroundStyle(.white)
                .shadow(radius: 4)
                .padding(12)
        }
        .frame(width: 180, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens events near you")
    }

    var body: some View {
        // A VStack (not a Group): an empty Group never starts its .task, so the row never loaded.
        VStack(alignment: .leading, spacing: 0) {
            if events.isEmpty {
                // Static images that are always there (built into the app), so the bottom is never empty.
                // Tapping one opens the Events list. Real events replace them once they load.
                VStack(alignment: .leading, spacing: 10) {
                    Text("HAPPENING NEAR YOU")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(NorthstarChatStyle.label)
                        .accessibilityAddTraits(.isHeader)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Self.categories, id: \.image) { c in
                                Button { onBrowse?() } label: { categoryCard(c) }
                                    .buttonStyle(.plain)
                                    .disabled(onBrowse == nil)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                    Text(finished ? "Tap to see events near you" : "Finding events near you\u{2026}")
                        .font(.caption2)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
                .padding(.top, 8)
            } else if !events.isEmpty {
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
        // Location can take a moment on first open, so try again a few times before giving up.
        .task {
            for attempt in 0..<4 {
                events = await NearbyEvents.load()
                if !events.isEmpty || Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(Double(attempt + 1) * 2))
            }
            finished = true
        }
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
            .frame(width: 280, height: 170)
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
        .frame(width: 280, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows tickets, directions and add to calendar")
    }
}

/// The Events tile: every event nearby as big image cards you swipe left and right, soonest first.
struct NearbyEventsList: View {
    @State private var events: [NearbyEvent] = []
    @State private var loading = true
    @State private var open: NearbyEvent?
    /// Another city they picked ("" = where they are). Kept for next time.
    @AppStorage("ns.eventsCity") private var chosenCity = ""
    @State private var editingCity = false
    @State private var cityDraft = ""
    @State private var hereName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(chosenCity.isEmpty ? "Happening near you" : "Happening in \(Self.short(chosenCity))")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(NorthstarChatStyle.text)
                .accessibilityAddTraits(.isHeader)

            cityBar

            if loading {
                HStack(spacing: 10) {
                    ProgressView().tint(NorthstarChatStyle.text)
                    Text(chosenCity.isEmpty ? "Finding events near you…" : "Finding events in \(Self.short(chosenCity))…")
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
                .padding(.vertical, 8)
            } else if events.isEmpty {
                Text(chosenCity.isEmpty
                     ? "I couldn't find events near you right now. If Location is off for Northstar, turn it on in iPhone Settings, then try again. Or tap Change city."
                     : "I couldn't find events in \(chosenCity) right now. Check the spelling, or try a bigger city nearby.")
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await load() } }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .frame(minHeight: 44)
            } else {
                // Swipe left and right, one big image card at a time (the next one peeks in).
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(events) { e in
                            Button { open = e } label: { card(e) }
                                .buttonStyle(.plain)
                                .containerRelativeFrame(.horizontal) { width, _ in width * 0.86 }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
                Text("Swipe for more · \(events.count) events")
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.soft)
                // Four more events with real photos, in a 2×2 grid, to fill the page.
                if !moreFour.isEmpty {
                    Text("MORE TO DO")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(NorthstarChatStyle.label)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(moreFour) { e in
                            Button { open = e } label: { tile(e) }
                                .buttonStyle(.plain)
                        }
                    }
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

    /// Up to 4 events with their own photo (not our built-in night-sky card), skipping the first one on screen.
    private var moreFour: [NearbyEvent] {
        let real = events.dropFirst().filter { !$0.image.absoluteString.contains("/assets/events/") }
        let pick = Array(real.prefix(4))
        return pick.count >= 2 ? Array(pick.prefix(pick.count >= 4 ? 4 : 2)) : []
    }

    private func tile(_ e: NearbyEvent) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: e.image) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { NorthstarChatStyle.card }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(e.whenText)
                    .font(.caption)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(10)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows tickets, directions and add to calendar")
    }

    private func load() async {
        loading = true
        events = await NearbyEvents.load(chosenCity: chosenCity)
        if chosenCity.isEmpty { hereName = await NearMe.shared.cityName() }
        loading = false
    }

    /// "Austin, TX, USA" → "Austin"
    static func short(_ city: String) -> String {
        city.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? city
    }

    // 📍 Which city, and a way to change it.
    @ViewBuilder
    private var cityBar: some View {
        if editingCity {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(NorthstarChatStyle.soft)
                    TextField("Type a city, like Austin, TX", text: $cityDraft)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(useDraft)
                    Button("Go", action: useDraft)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 14)
                .background(Capsule().fill(NorthstarChatStyle.card))
                .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke))
                HStack(spacing: 16) {
                    Button {
                        chosenCity = ""
                        editingCity = false
                        Task { await load() }
                    } label: {
                        Label("Use my location", systemImage: "location")
                    }
                    Button("Cancel") { editingCity = false }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NorthstarChatStyle.linkBlue)
                .frame(minHeight: 44)
            }
        } else {
            HStack(spacing: 10) {
                Label(chosenCity.isEmpty ? (hereName.map { Self.short($0) } ?? "Near you") : chosenCity,
                      systemImage: chosenCity.isEmpty ? "location.fill" : "mappin.and.ellipse")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    cityDraft = ""
                    editingCity = true
                } label: {
                    Text("Change city")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows events in another city")
            }
        }
    }

    private func useDraft() {
        let city = cityDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else { return }
        chosenCity = city
        editingCity = false
        Task { await load() }
    }

    private func card(_ e: NearbyEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: e.image) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { NorthstarChatStyle.card }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(e.name)
                    .font(.headline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .lineLimit(2, reservesSpace: true)
                Text([e.whenText, [e.venue, e.city].filter { !$0.isEmpty }.joined(separator: ", "),
                      e.miles.map { String(format: $0 < 10 ? "%.1f mi" : "%.0f mi", $0) }]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .lineLimit(2, reservesSpace: true)
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
