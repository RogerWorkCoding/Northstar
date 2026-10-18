import SwiftUI
import MapKit

// 🛎 Concierge cards: places (map + Reserve, Call, Ride, Order), products to compare, and the call script.
// Every button opens another app or the phone; Northstar itself never books, orders or pays.

// MARK: - Places: a small map and one card per place

struct ConciergePicks: View {
    let places: [NorthstarInsight.Place]
    let kind: ConciergeView.Service.Kind
    let booking: NorthstarInsight.Booking

    struct Pick: Identifiable {
        let id = UUID()
        let place: NorthstarInsight.Place
        let item: MKMapItem?
        let miles: Double?
    }

    @State private var picks: [Pick] = []
    @State private var searched = false
    @State private var scriptFor: Pick?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let pinned = picks.filter { $0.item != nil }
            if !pinned.isEmpty {
                Map(initialPosition: .automatic, interactionModes: []) {
                    ForEach(Array(pinned.enumerated()), id: \.element.id) { index, p in
                        if let item = p.item {
                            Marker("\(index + 1)", coordinate: item.location.coordinate)
                        }
                    }
                    UserAnnotation()
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                .accessibilityLabel("Map of \(pinned.map(\.place.name).joined(separator: ", "))")
            } else if !searched {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NorthstarChatStyle.card)
                    .frame(height: 170)
                    .overlay(ProgressView().tint(NorthstarChatStyle.text))
            }

            ForEach(Array((searched ? picks : places.map { Pick(place: $0, item: nil, miles: nil) }).enumerated()), id: \.element.id) { index, p in
                card(p, number: index + 1)
            }
        }
        .task { await search() }
        .sheet(item: $scriptFor) { p in
            CallScriptSheet(name: p.place.name, phone: phoneURL(p), location: p.item?.address?.shortAddress ?? p.place.area,
                            kind: kind, booking: booking)
                .presentationDetents([.large])
        }
    }

    private func card(_ p: Pick, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number) · \(p.place.name)")
                    .font(.headline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let miles = p.miles {
                    Text(String(format: miles < 10 ? "%.1f mi" : "%.0f mi", miles))
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
            }
            Text(p.item?.address?.shortAddress ?? p.place.area)
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .lineLimit(2)

            if let t = p.place.tonight {
                tonightBlock(t)
            }

            if let why = p.place.why, !why.isEmpty {
                Text("Why for you: \(why)")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                switch kind {
                case .dinner:
                    pill("Reserve", primary: true) { reserve(p) }
                case .home:
                    if p.item?.url != nil { pill("Website", primary: true) { if let u = p.item?.url { openURL(u) } } }
                default:
                    if let url = p.item?.url { pill("Website", primary: true) { openURL(url) } }
                }
                if phoneURL(p) != nil {
                    // Call opens the script first: what to say, then one tap to dial.
                    pill("Call", primary: kind == .home && p.item?.url == nil) { scriptFor = p }
                }
                more(p)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    /// ✦ TONIGHT: the special, then where it came from and how fresh (tap to check the source).
    private func tonightBlock(_ t: NorthstarInsight.Place.Tonight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                Text("TONIGHT").tracking(1.5)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.starGold)
            Text(t.text)
                .font(.body.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)
                .fixedSize(horizontal: false, vertical: true)
            Button { openURL(t.url) } label: {
                HStack(spacing: 4) {
                    Text("From \(t.source) · \(t.posted.lowercased() == "today" ? "posted today" : t.posted)")
                    Image(systemName: "arrow.up.right").font(.caption2.weight(.semibold))
                }
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the source to check it")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NorthstarChatStyle.cardStrong))
    }

    /// Ride, directions and (for dinner) delivery.
    private func more(_ p: Pick) -> some View {
        Menu {
            Section("Get there") {
                Button("Uber", systemImage: "car") { ride(p, uber: true) }
                Button("Lyft", systemImage: "car") { ride(p, uber: false) }
                Button("Directions in Maps", systemImage: "map") { directions(p) }
            }
            if kind == .dinner {
                Section("Order delivery") {
                    Button("DoorDash", systemImage: "bag") { order(p, doorDash: true) }
                    Button("Uber Eats", systemImage: "bag") { order(p, doorDash: false) }
                }
            }
        } label: {
            Text(kind == .dinner ? "Ride / Order" : "Ride")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 40)
                .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        }
    }

    private func pill(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary ? NorthstarChatStyle.onPrimary : NorthstarChatStyle.text)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(primary ? NorthstarChatStyle.primaryFill : Color.clear))
                .overlay(Capsule().strokeBorder(primary ? Color.clear : NorthstarChatStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func phoneURL(_ p: Pick) -> URL? {
        guard let phone = p.item?.phoneNumber else { return nil }
        return URL(string: "tel:" + phone.filter { "0123456789+".contains($0) })
    }

    // MARK: Find each place in Apple Maps

    private func search() async {
        let here = await NearMe.shared.currentLocation()
        var out: [Pick] = []
        for place in places.prefix(5) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "\(place.name), \(place.area)"
            request.resultTypes = [.pointOfInterest, .address]
            let item = try? await MKLocalSearch(request: request).start().mapItems.first
            guard !Task.isCancelled else { return }
            let miles = item.flatMap { i in here.map { i.location.distance(from: $0) / 1609.34 } }
            out.append(Pick(place: place, item: item, miles: miles))
        }
        picks = out
        searched = true
    }

    // MARK: Buttons (each opens another app; Northstar itself never books or pays)

    /// OpenTable, already set to their party size, day and time when they've said them.
    private func reserve(_ p: Pick) {
        var parts = URLComponents(string: "https://www.opentable.com/s")!
        var items = [URLQueryItem(name: "term", value: "\(p.place.name) \(p.place.area)")]
        if let party = booking.party { items.append(URLQueryItem(name: "covers", value: String(party))) }
        if let date = booking.date {
            items.append(URLQueryItem(name: "dateTime", value: "\(date)T\(booking.time ?? "19:00")"))
        }
        parts.queryItems = items
        if let url = parts.url { openURL(url) }
    }

    private func order(_ p: Pick, doorDash: Bool) {
        let name = p.place.name
        let url: URL?
        if doorDash {
            let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            url = URL(string: "https://www.doordash.com/search/store/\(path)/")
        } else {
            var parts = URLComponents(string: "https://www.ubereats.com/search")!
            parts.queryItems = [URLQueryItem(name: "q", value: name)]
            url = parts.url
        }
        if let url { openURL(url) }
    }

    private func ride(_ p: Pick, uber: Bool) {
        guard let item = p.item else { return directions(p) }
        let c = item.location.coordinate
        var parts: URLComponents
        if uber {
            parts = URLComponents(string: "https://m.uber.com/ul/")!
            parts.queryItems = [
                URLQueryItem(name: "action", value: "setPickup"),
                URLQueryItem(name: "pickup", value: "my_location"),
                URLQueryItem(name: "dropoff[latitude]", value: String(c.latitude)),
                URLQueryItem(name: "dropoff[longitude]", value: String(c.longitude)),
                URLQueryItem(name: "dropoff[nickname]", value: p.place.name),
            ]
        } else {
            parts = URLComponents(string: "https://lyft.com/ride")!
            parts.queryItems = [
                URLQueryItem(name: "id", value: "lyft"),
                URLQueryItem(name: "destination[latitude]", value: String(c.latitude)),
                URLQueryItem(name: "destination[longitude]", value: String(c.longitude)),
            ]
        }
        if let url = parts.url { openURL(url) }
    }

    private func directions(_ p: Pick) {
        if let item = p.item {
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        } else {
            var parts = URLComponents(string: "https://maps.apple.com/")!
            parts.queryItems = [URLQueryItem(name: "daddr", value: "\(p.place.name), \(p.place.area)")]
            if let url = parts.url { openURL(url) }
        }
    }
}

// MARK: - Products: the top 3 to compare

struct ProductCards: View {
    let products: [NorthstarInsight.Product]
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(products.enumerated()), id: \.element) { index, p in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(index + 1) · \(p.name)")
                            .font(.headline)
                            .foregroundStyle(NorthstarChatStyle.text)
                            .lineLimit(3)
                        Spacer(minLength: 8)
                        if let price = p.price, !price.isEmpty {
                            Text(price)
                                .font(.headline)
                                .foregroundStyle(NorthstarChatStyle.text)
                        }
                    }
                    let details = [p.store, p.rating].compactMap { $0 }.filter { !$0.isEmpty }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.label)
                    }
                    if let why = p.why, !why.isEmpty {
                        Text(why)
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button { openURL(p.url) } label: {
                        Label("View\(p.store.map { $0.isEmpty ? "" : " at \($0)" } ?? "")", systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.onPrimary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the store page in Safari")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                .accessibilityElement(children: .contain)
            }
            Text("Prices can change. Check the store before you buy.")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
        }
    }
}

// MARK: - Call with a script: what to say, one tap to dial, then "Booked it" adds it to the calendar

struct CallScriptSheet: View {
    let name: String
    let phone: URL?
    let location: String
    let kind: ConciergeView.Service.Kind
    let booking: NorthstarInsight.Booking

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKeys.preferredName) private var preferredName = ""

    @State private var booked = false
    @State private var when = Date()
    @State private var saved: String?
    @State private var problem: String?

    private var isTable: Bool { kind == .dinner }

    private var say: String {
        let who = preferredName.trimmingCharacters(in: .whitespaces)
        let nameLine = who.isEmpty ? "" : " The name is **\(who)**."
        if isTable {
            let party = booking.party.map { "**\($0)**" } ?? "**[how many]**"
            let day = booking.dayText.map { " **\($0)**" } ?? ""
            let time = booking.timeText.map { " at **\($0)**" } ?? ""
            return "\"Hi, I'd like a table for \(party)\(day.isEmpty ? "" : " on")\(day)\(time).\(nameLine)\""
        }
        return "\"Hi, I'm looking for help at my home. When is your next opening, and what does a visit cost?\(nameLine)\""
    }

    private var ifNot: String {
        if isTable {
            if let start = booking.start, booking.time != nil {
                let later = start.addingTimeInterval(30 * 60).formatted(date: .omitted, time: .shortened)
                let latest = start.addingTimeInterval(60 * 60).formatted(date: .omitted, time: .shortened)
                return "\"Do you have anything around **\(later)** or **\(latest)**?\""
            }
            return "\"What times do you have open?\""
        }
        return "\"Are you licensed and insured?\""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NorthstarChatStyle.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(NorthstarChatStyle.text)
                            Text(location)
                                .font(.subheadline)
                                .foregroundStyle(NorthstarChatStyle.soft)
                        }

                        step("1", "SAY", say)
                        step("2", isTable ? "IF THAT'S FULL, ASK" : "ALSO ASK", ifNot)

                        if let phone {
                            Button { openURL(phone) } label: {
                                Label("Call \(name)", systemImage: "phone.fill")
                                    .font(.headline)
                                    .foregroundStyle(NorthstarChatStyle.onPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                            }
                            .buttonStyle(.plain)
                            Text("Tip: during the call, come back to Northstar to read this.")
                                .font(.footnote)
                                .foregroundStyle(NorthstarChatStyle.label)
                        }

                        Divider().overlay(NorthstarChatStyle.stroke)

                        if let problem {
                            Text(problem)
                                .font(.subheadline)
                                .foregroundStyle(NorthstarChatStyle.warning)
                        }
                        if let saved {
                            Label(saved, systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(NorthstarChatStyle.savedGreen)
                        } else if booked {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("When is it?")
                                    .font(.headline)
                                    .foregroundStyle(NorthstarChatStyle.text)
                                DatePicker("When", selection: $when)
                                    .labelsHidden()
                                    .tint(NorthstarChatStyle.linkBlue)
                                Button { addToCalendar() } label: {
                                    Label("Add to calendar", systemImage: "calendar.badge.plus")
                                        .font(.headline)
                                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Button { booked = true } label: {
                                Text(isTable ? "✅ Booked it" : "✅ Set it up")
                                    .font(.headline)
                                    .foregroundStyle(NorthstarChatStyle.text)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Then add it to your calendar")
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { when = booking.start ?? Self.nextHour() }
    }

    private func step(_ number: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number) · \(title)")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(NorthstarChatStyle.label)
            Text(NorthstarReplyView.formatted(text))
                .font(.system(size: 22))
                .foregroundStyle(NorthstarChatStyle.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }

    private func addToCalendar() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let t = DateFormatter()
        t.locale = Locale(identifier: "en_US_POSIX")
        t.dateFormat = "HH:mm"
        let title = isTable ? (booking.party.map { "\(name) (table for \($0))" } ?? name) : name
        let item = NorthstarInsight.Schedule(kind: "event", title: title, date: f.string(from: when), time: t.string(from: when),
                                             minutes: isTable ? 90 : 60, alertMinutes: 60, location: location, repeatRule: nil)
        problem = nil
        Task {
            do {
                let place = try await NorthstarCalendar.shared.add(item)
                saved = "Added to \(place)"
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    private static func nextHour() -> Date {
        let cal = Calendar.current
        let next = cal.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return cal.date(bySetting: .minute, value: 0, of: next) ?? next
    }
}
