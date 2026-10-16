import SwiftUI
import MapKit

// 🛎 Concierge: visual and voice-first.
// Pick what you need (Dinner, Fitness…). Northstar works in the background and the picks appear here
// as cards with a small map and buttons: Reserve, Call, Ride. Need more? Tap the mic and say it,
// or tap a quick answer ("For 4", "Saturday"). The conversation runs behind the scenes.
// Northstar shows options; you choose. It never books or pays.

struct ConciergeView: View {
    /// What Northstar remembers (with memory on), so picks fit the person.
    var memory: () async -> [NorthstarEngineClient.MemoryItem] = { [] }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // The background conversation for this Concierge visit.
    @State private var turns: [MessageModel] = []
    @State private var service: Service?
    @State private var working = false
    @State private var line = ""          // Northstar's short line at the top
    @State private var places: [NorthstarInsight.Place] = []
    @State private var typed = ""
    @State private var speech = SpeechRecognizer()
    @State private var micMessage: String?
    @State private var task: Task<Void, Never>?
    @State private var silence: Task<Void, Never>?
    @FocusState private var typing: Bool

    private let engine = NorthstarEngineClient()

    struct Service: Identifiable, Hashable {
        let id: String
        let title: String
        let icon: String
        let request: String
        let quick: [String]
        /// Dinner: Reserve opens a reservation search.
        var reserves: Bool = false
    }

    private let services: [Service] = [
        .init(id: "dinner", title: "Dinner", icon: "fork.knife",
              request: "Find me 3 good places for dinner near me.",
              quick: ["For 2", "For 4", "Tonight", "Saturday", "Quieter", "Cheaper"], reserves: true),
        .init(id: "fitness", title: "Fitness", icon: "figure.yoga",
              request: "Find 3 fitness classes or gyms near me.",
              quick: ["Yoga", "Pilates", "Beginners", "Mornings", "Evenings"]),
        .init(id: "fun", title: "Fun", icon: "sparkles",
              request: "Find 3 fun things to do near me this week.",
              quick: ["Outdoors", "With kids", "Date night", "Free", "Saturday"]),
        .init(id: "travel", title: "Travel", icon: "airplane",
              request: "Help me with travel: a ride, a hotel or a flight. Ask me which one and where I'm going, then show the best 3 options.",
              quick: ["Ride", "Hotel", "Flight", "Airport", "This weekend"]),
        .init(id: "errands", title: "Errands", icon: "bag",
              request: "Find the 3 nearest open pharmacies or stores near me.",
              quick: ["Pharmacy", "Grocery", "Hardware", "Open now"]),
        .init(id: "gifts", title: "Gifts", icon: "gift",
              request: "Help me find a good gift. Suggest 3 local shops near me.",
              quick: ["Under $25", "Under $50", "For her", "For him", "Handmade"]),
    ]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if service == nil {
                            menu
                        } else {
                            results
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                if service != nil { askBar }
            }
        }
        .onChange(of: speech.transcript) {
            guard speech.isRecording else { return }
            typed = speech.transcript
            // Hands-free: when they stop talking for a moment, send it.
            silence?.cancel()
            let heard = speech.transcript
            silence = Task {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled, speech.isRecording, speech.transcript == heard,
                      !heard.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                speech.stopRecording()
                ask(heard)
            }
        }
        .onDisappear {
            task?.cancel()
            if speech.isRecording { speech.stopRecording() }
            NorthstarVoice.shared.stop()
        }
        .alert("Voice input", isPresented: Binding(get: { micMessage != nil }, set: { if !$0 { micMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(micMessage ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            if service != nil {
                Button {
                    startOver()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back to Concierge")
            }
            Label {
                Text(service?.title ?? "Concierge").font(.headline)
            } icon: {
                Image(systemName: service?.icon ?? "bell").foregroundStyle(NorthstarChatStyle.starGold)
            }
            .foregroundStyle(NorthstarChatStyle.text)
            Spacer()
            Button("Close") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.linkBlue)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: The six services

    private var menu: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What do you need?")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Pick one. I'll find a few good options, and you choose.")
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(services) { s in
                    Button { start(s) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: s.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(NorthstarChatStyle.linkBlue)
                            Text(s.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(NorthstarChatStyle.text)
                        }
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Label("Northstar never books or pays without you.", systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    // MARK: Results

    private var results: some View {
        VStack(alignment: .leading, spacing: 16) {
            if working {
                HStack(spacing: 10) {
                    ProgressView().tint(NorthstarChatStyle.text)
                    Text("Looking for good options…")
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
                .padding(.vertical, 8)
            } else if !line.isEmpty {
                Text(line)
                    .font(.system(size: 18))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if !places.isEmpty {
                ConciergePicks(places: places, reserves: service?.reserves == true)
                    .id(places)
            }

            if let service, !working {
                quickAnswers(service)
            }

            Label("Northstar never books or pays without you.", systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func quickAnswers(_ s: Service) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(s.quick, id: \.self) { q in
                    Button { ask(q) } label: {
                        Text(q)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(NorthstarChatStyle.card))
                            .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityLabel("Quick answers")
    }

    // MARK: Ask bar: the mic first

    private var askBar: some View {
        // Same order as the main ask bar: words on the left, mic and send on the right.
        HStack(spacing: 10) {
            TextField(speech.isRecording ? "Listening…" : "Say or type what you want", text: $typed, axis: .vertical)
                .focused($typing)
                .lineLimit(1...3)
                .foregroundStyle(NorthstarChatStyle.text)
                .submitLabel(.send)
                .onSubmit { ask(typed) }

            Button { toggleMic() } label: {
                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(speech.isRecording ? .white : NorthstarChatStyle.onPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(speech.isRecording ? NorthstarChatStyle.listening : NorthstarChatStyle.primaryFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speech.isRecording ? "Stop and send" : "Speak")

            if !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !speech.isRecording {
                Button { ask(typed) } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(NorthstarChatStyle.sendFill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(NorthstarChatStyle.background)
    }

    // MARK: Actions

    private func start(_ s: Service) {
        service = s
        turns = []
        places = []
        line = ""
        Task {
            var request = s.request
            if let city = await NearMe.shared.cityName() {
                request += " I'm in \(city)."
            }
            ask(request)
        }
    }

    private func startOver() {
        task?.cancel()
        if speech.isRecording { speech.stopRecording() }
        NorthstarVoice.shared.stop()
        service = nil
        turns = []
        places = []
        line = ""
        typed = ""
        working = false
    }

    private func ask(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Always turn the mic off when something is sent (by voice, keyboard or a quick answer).
        silence?.cancel()
        if speech.isRecording { speech.stopRecording() }
        guard !clean.isEmpty, !working else { return }
        typed = ""
        typing = false
        NorthstarVoice.shared.stop()
        turns.append(MessageModel(role: .user, content: clean))
        working = true
        task = Task {
            let settings = EngineSettings.current
            let remembered = settings.memoryOn ? await memory() : []
            let answer = await engine.getReply(for: turns, memory: remembered, settings: settings)
            guard !Task.isCancelled else { return }
            working = false
            turns.append(MessageModel(role: .assistant, content: answer.text, insight: answer.insight))
            line = Self.shortLine(answer.text)
            if let found = answer.insight?.places, !found.isEmpty { places = found }
            if NorthstarVoice.autoSpeak, !answer.failed { NorthstarVoice.shared.speak(line) }
        }
    }

    private func toggleMic() {
        NorthstarVoice.shared.stop()
        if speech.isRecording {
            silence?.cancel()
            let words = typed
            speech.stopRecording()
            ask(words)
            return
        }
        Task {
            guard await speech.requestPermissions() else {
                micMessage = "Northstar needs microphone and speech access. You can turn them on in Settings › Privacy & Security."
                return
            }
            do {
                typed = ""
                try speech.startRecording()
            } catch {
                micMessage = "Northstar couldn't start listening. Please try again."
            }
        }
    }

    /// The reply's opening words, before any list (the cards show the list).
    nonisolated static func shortLine(_ text: String) -> String {
        var kept: [String] = []
        for raw in text.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("•") || l.hasPrefix("-") || l.hasPrefix("*") || l.first?.isNumber == true && l.dropFirst().hasPrefix(".") {
                if !kept.isEmpty { break } else { continue }
            }
            if l.isEmpty { if !kept.isEmpty { break } else { continue } }
            kept.append(l)
        }
        let joined = kept.joined(separator: " ")
        let plain = joined.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
        return plain.isEmpty ? text : plain
    }
}

// MARK: - The picks: a small map and one card per place

private struct ConciergePicks: View {
    let places: [NorthstarInsight.Place]
    let reserves: Bool

    struct Pick: Identifiable {
        let id = UUID()
        let place: NorthstarInsight.Place
        let item: MKMapItem?
        let miles: Double?
    }

    @State private var picks: [Pick] = []
    @State private var searched = false
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

            HStack(spacing: 8) {
                if reserves {
                    pill("Reserve", primary: true) { reserve(p) }
                } else if let url = p.item?.url {
                    pill("Website", primary: true) { openURL(url) }
                }
                if let phone = p.item?.phoneNumber,
                   let url = URL(string: "tel:" + phone.filter { "0123456789+".contains($0) }) {
                    pill("Call", primary: false) { openURL(url) }
                }
                Menu {
                    Button("Uber") { ride(p, uber: true) }
                    Button("Lyft") { ride(p, uber: false) }
                    Button("Directions in Maps") { directions(p) }
                } label: {
                    Text("Ride")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.text)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .overlay(Capsule().strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .contain)
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

    private func reserve(_ p: Pick) {
        var parts = URLComponents(string: "https://www.opentable.com/s")!
        parts.queryItems = [URLQueryItem(name: "term", value: "\(p.place.name) \(p.place.area)")]
        if let url = parts.url { openURL(url) }
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

#Preview {
    ConciergeView()
}
