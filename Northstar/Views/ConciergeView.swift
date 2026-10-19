import SwiftUI
import MapKit

// 🛎 Concierge: visual and voice-first.
// Pick what you need (Dinner, Shopping, Home…). Northstar works in the background and the picks appear
// here as cards: places with a small map and buttons (Reserve, Call, Ride, Order), products with a View
// button, or a short answer with sources (Look It Up). Need more? Tap the mic and say it, or tap a quick
// answer ("For 4", "Saturday"). Below the tiles: images of events happening nearby.
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
    @State private var products: [NorthstarInsight.Product] = []
    @State private var listings: [NorthstarInsight.Listing] = []
    @State private var city: String?
    @State private var sources: [NorthstarInsight.Source] = []
    @State private var answer = ""        // Look It Up: the full answer
    @State private var booking = NorthstarInsight.Booking()
    // Home & Services only: Northstar's one recommended provider (see Views/HomeServices).
    @State private var homeState: HomeServicesState?
    @State private var homeNeed = ""
    /// Which page of tiles is showing (tiles swipe left and right).
    @State private var tilePage: Int? = 0
    // Exact location or city only: asked once with a clear notice, changeable any time.
    @State private var showLocationNotice = false
    @State private var preciseOn = NearMe.precise

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
        var kind: Kind = .places

        enum Kind { case places, dinner, shopping, home, lookUp, events, apartments }
    }

    private let services: [Service] = [
        .init(id: "dinner", title: "Dinner", icon: "fork.knife",
              request: "Find me 3 good places for dinner near me.",
              quick: ["Date night", "With kids", "Catch up with friends", "Quick bite", "For 4", "Saturday", "Delivery"], kind: .dinner),
        .init(id: "shopping", title: "Shopping", icon: "cart",
              request: "Help me shop. Ask me what I'm looking for, then compare the top 3 with prices.",
              quick: ["A gift", "Under $50", "Under $100", "Best rated", "Buy local"], kind: .shopping),
        .init(id: "fun", title: "Fun", icon: "sparkles",
              request: "Find 3 fun things to do near me this week.",
              quick: ["Outdoors", "With kids", "Date night", "Free", "Saturday"]),
        .init(id: "events", title: "Events", icon: "ticket",
              request: "", quick: [], kind: .events),
        .init(id: "fitness", title: "Fitness", icon: "figure.yoga",
              request: "Find 3 fitness classes or gyms near me.",
              quick: ["Yoga", "Pilates", "Beginners", "Mornings", "Evenings"]),
        .init(id: "travel", title: "Travel", icon: "airplane",
              request: "Help me with travel: a ride, a hotel or a flight. Ask me which one and where I'm going, then show the best 3 options.",
              quick: ["Ride", "Hotel", "Flight", "Airport", "This weekend"]),
        .init(id: "ev", title: "EV Charging", icon: "bolt.car",
              request: "Find EV chargers near me: the best 3 fast chargers, with the network, speed and how many plugs.",
              quick: ["Fast charging", "On my way home", "Open 24 hours", "Near food", "Cheapest"]),
        .init(id: "errands", title: "Errands", icon: "bag",
              request: "Find the 3 nearest open pharmacies or stores near me.",
              quick: ["Pharmacy", "Grocery", "Hardware", "Post office", "Open now"]),
        .init(id: "home", title: "Home & Services", icon: "wrench.and.screwdriver",
              request: "I need help at home. Ask me what kind (plumber, electrician, cleaner, handyman, car repair or pet care), then find 3 well-reviewed local ones.",
              quick: ["Plumber", "Electrician", "Cleaner", "Handyman", "Car repair", "Pet care"], kind: .home),
        .init(id: "apartments", title: "Apartments", icon: "building.2",
              request: "Help me find an apartment to rent. Ask what's missing (area, budget, bedrooms, move-in date, pets), one thing at a time, then show the best 3 real listings with a scam check and the true monthly cost.",
              quick: ["Under $2,000", "Under $2,500", "1 bedroom", "2 bedrooms", "Pet friendly", "Move in soon", "In-unit laundry"],
              kind: .apartments),
        .init(id: "lookup", title: "Look It Up", icon: "magnifyingglass",
              request: "",
              quick: ["Is it open now?", "Weather this weekend", "Gas prices near me", "Compare two things"], kind: .lookUp),
    ]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

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
                if service != nil, service?.kind != .events { askBar }
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
        .onAppear {
            if NearMe.preciseChoice == nil { showLocationNotice = true }
        }
        .alert("Use your exact location?", isPresented: $showLocationNotice) {
            Button("Use exact location") { setPrecise(true) }
            Button("City only") { setPrecise(false) }
        } message: {
            Text("Northstar can find what's really closest to you: chargers, events and help at home. Your location is sent only when you search, rounded to about a block, and Northstar doesn't save it. You can change this any time at the bottom of the Concierge.")
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

            // Tiles in pages of 6 (2 across, 3 down). Swipe left and right for more,
            // so new services can keep being added without making the page longer.
            tilePages

            NearbyEventsRow {
                if let events = services.first(where: { $0.kind == .events }) { start(events) }
            }

            Label("Northstar never books or pays without you.", systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Button { showLocationNotice = true } label: {
                Label(preciseOn ? "Location: exact (about a block) \u{00B7} Change" : "Location: city only \u{00B7} Change",
                      systemImage: preciseOn ? "location.fill" : "location")
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose exact location or city only")
        }
    }

    private var pages: [[Service]] {
        stride(from: 0, to: services.count, by: 6).map { Array(services[$0..<min($0 + 6, services.count)]) }
    }

    private var tilePages: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(page) { s in tile(s) }
                        }
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $tilePage)
            .scrollClipDisabled()

            if pages.count > 1 {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == (tilePage ?? 0) ? NorthstarChatStyle.text : NorthstarChatStyle.label.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                    Text("Swipe for more")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.soft)
                        .padding(.leading, 4)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \((tilePage ?? 0) + 1) of \(pages.count). Swipe left or right for more services.")
            }
        }
    }

    private func tile(_ s: Service) -> some View {
        Button { start(s) } label: {
            HStack(spacing: 10) {
                Image(systemName: s.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .frame(width: 28)
                Text(s.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Results

    private var results: some View {
        VStack(alignment: .leading, spacing: 16) {
            if service?.kind == .events {
                NearbyEventsList()
            } else if working {
                HStack(spacing: 10) {
                    ProgressView().tint(NorthstarChatStyle.text)
                    Text("Looking for good options…")
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
                .padding(.vertical, 8)
            } else if service?.kind == .lookUp, !answer.isEmpty {
                Text(NorthstarReplyView.formatted(answer))
                    .font(.system(size: 18))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .tint(NorthstarChatStyle.linkBlue)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else if !line.isEmpty {
                Text(line)
                    .font(.system(size: 18))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if service?.kind == .home, let homeState {
                HomeServicesResultsView(need: homeNeed, state: homeState) { findProviders(homeNeed) }
            }

            if !listings.isEmpty {
                ApartmentCards(listings: listings, city: city)
            }

            if !products.isEmpty {
                ProductCards(products: products)
            }

            if !places.isEmpty, let service {
                ConciergePicks(places: places, kind: service.kind, booking: booking)
                    .id(places)
            }

            if !sources.isEmpty, !working {
                SourcesRow(sources: sources)
            }

            if let service, service.kind != .events, !working {
                quickAnswers(service)
            }

            // Fun also shows what's happening nearby.
            if service?.id == "fun", !working {
                NearbyEventsRow()
            }

            Label("Northstar never books or pays without you.", systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func quickAnswers(_ s: Service) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if s.kind == .dinner, !places.isEmpty {
                Text("What's the night about?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.soft)
            }
            if s.kind == .home, homeState == nil {
                homeTiles(s)      // first choice: big icon tiles
            } else {
                quickChips(s)
            }
        }
    }

    /// Home & Services' first step: big gold icons you can spot before reading the word.
    /// (Real images only appear for real businesses, on the recommendation.)
    private func homeTiles(_ s: Service) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(s.quick, id: \.self) { q in
                Button { ask(q) } label: {
                    VStack(spacing: 10) {
                        Image(systemName: Self.homeIcon(q))
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(HomeServicesStyle.gold)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(HomeServicesStyle.gold.opacity(0.14)))
                            .accessibilityHidden(true)
                        Text(q)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.text)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Finds the provider Northstar recommends")
            }
        }
    }

    nonisolated static func homeIcon(_ name: String) -> String {
        switch name {
        case "Plumber": "drop.fill"
        case "Electrician": "bolt.fill"
        case "Cleaner": "bubbles.and.sparkles.fill"
        case "Handyman": "hammer.fill"
        case "Car repair": "car.fill"
        case "Pet care": "pawprint.fill"
        default: "wrench.and.screwdriver.fill"
        }
    }

    private func quickChips(_ s: Service) -> some View {
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
            if speech.isRecording {
                VoiceBars(level: speech.level, color: NorthstarChatStyle.listening, count: typed.isEmpty ? 12 : 5)
            }
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
                    .background { ListeningRing(active: speech.isRecording, color: NorthstarChatStyle.listening) }
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
        clearResults()
        booking = .init()
        if s.kind == .events { return }  // a list of real events, no chat needed
        if s.kind == .home {
            // Keep the choice screen: pick a trade or say what's wrong, then one recommendation.
            line = "What kind of help do you need? Pick one, or tell me what's wrong."
            return
        }
        if s.kind == .lookUp {
            line = "What should I look up? Say it or type it."
            typing = true
            return
        }
        Task {
            var request = s.request
            if let found = await NearMe.shared.cityName() {
                city = found
                let near = await NearMe.shared.nearText() ?? "in \(found)"
                request += " I'm \(near)."
            }
            ask(request)
        }
    }

    private func setPrecise(_ on: Bool) {
        NearMe.preciseChoice = on
        preciseOn = on
    }

    private func startOver() {
        task?.cancel()
        if speech.isRecording { speech.stopRecording() }
        NorthstarVoice.shared.stop()
        service = nil
        turns = []
        clearResults()
        booking = .init()
        typed = ""
        working = false
    }

    private func clearResults() {
        places = []
        products = []
        listings = []
        sources = []
        answer = ""
        line = ""
        homeState = nil
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
        if service?.kind == .home {
            findProviders(clean)
            return
        }
        turns.append(MessageModel(role: .user, content: clean))
        working = true
        task = Task {
            let settings = EngineSettings.current
            let remembered = settings.memoryOn ? await memory() : []
            let answer = await engine.getReply(for: turns, memory: remembered, settings: settings, source: "concierge")
            guard !Task.isCancelled else { return }
            working = false
            turns.append(MessageModel(role: .assistant, content: answer.text, insight: answer.insight))
            line = Self.shortLine(answer.text)
            self.answer = answer.text
            booking = booking.merged(with: answer.insight?.booking)
            if let found = answer.insight?.places, !found.isEmpty { places = found }
            if let found = answer.insight?.products, !found.isEmpty { products = found }
            if let found = answer.insight?.listings, !found.isEmpty { listings = found }
            sources = answer.insight?.sources ?? []
            if NorthstarVoice.autoSpeak, !answer.failed { NorthstarVoice.shared.speak(line) }
        }
    }

    /// Home & Services: compare local providers and recommend one (nothing is contacted or booked).
    private func findProviders(_ need: String) {
        task?.cancel()
        homeNeed = need
        line = ""
        homeState = .loading
        task = Task {
            let result = await HomeServicesProviderService.recommend(need: need)
            guard !Task.isCancelled else { return }
            homeState = result
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

#Preview {
    ConciergeView()
}
