import SwiftUI
import Supabase

// 🧭 Northstar Navigator, step 1 (owner preview): ask your Mac to FIND files. Look only.
// Shown only when the brain says this account is an owner (NS_ADMIN_USERS). See docs/navigator-step1.md.

// MARK: - Talking to northstar-navigator

nonisolated struct NavigatorMacInfo: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let last_seen: String?
}

nonisolated struct NavigatorFile: Decodable, Hashable, Sendable {
    let name: String
    let folder: String
    let modified: String?
    let kind: String?
}

nonisolated struct NavigatorEvent: Decodable, Hashable, Sendable {
    nonisolated struct Plan: Decodable, Hashable, Sendable { let say: String? }
    nonisolated struct Detail: Decodable, Hashable, Sendable {
        let request: String?
        let found: Int?
        let folders: [String]?
        let skipped_protected: Int?
        let changed: Int?
        let mac: String?
        let error: String?
        let plan: Plan?
    }
    let at: String
    let actor: String
    let kind: String
    let detail: Detail?

    /// Plain words for the record ("What Navigator did").
    var words: String {
        switch kind {
        case "asked": return "You asked: \u{201C}\(detail?.request ?? "")\u{201D}"
        case "picked_up": return "\(detail?.mac ?? "Your Mac") picked it up"
        case "planned": return "Plan: \(detail?.plan?.say ?? "search your folders") (look only)"
        case "searching": return "Searched: \((detail?.folders ?? []).joined(separator: ", "))"
        case "done":
            var s = "Found \(detail?.found ?? 0). Changed nothing."
            if let n = detail?.skipped_protected, n > 0 { s += " Skipped \(n) in protected places." }
            return s
        case "stopped", "stopped_on_mac": return "Stopped"
        case "failed": return "Problem: \(detail?.error ?? "unknown")"
        default: return kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var time: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: at) ?? ISO8601DateFormatter().date(from: at)
        return d?.formatted(date: .omitted, time: .standard) ?? ""
    }
}

nonisolated struct NavigatorTask: Decodable, Hashable, Sendable, Identifiable {
    nonisolated struct Result: Decodable, Hashable, Sendable {
        let files: [NavigatorFile]?
        let searched: [String]?
    }
    let id: String
    let request: String
    let status: String
    let created_at: String
    let result: Result?
    let error: String?
    let events: [NavigatorEvent]?

    var isActive: Bool { status == "queued" || status == "running" }
}

@MainActor
enum NavigatorService {
    nonisolated private struct Body: Encodable, Sendable {
        let action: String
        var text: String? = nil
        var task_id: String? = nil
        var device_id: String? = nil
    }
    nonisolated struct Status: Decodable, Sendable { let allowed: Bool?; let macs: [NavigatorMacInfo]? }
    nonisolated struct Code: Decodable, Sendable { let code: String?; let expires_at: String? }
    nonisolated struct Asked: Decodable, Sendable { let task_id: String? }
    nonisolated struct Tasks: Decodable, Sendable { let tasks: [NavigatorTask]? }
    nonisolated struct Ok: Decodable, Sendable { let ok: Bool? }

    private static func call<T: Decodable>(_ body: Body) async -> T? {
        try? await SupabaseManager.shared.client.functions.invoke(
            "northstar-navigator", options: FunctionInvokeOptions(body: body))
    }

    static func status() async -> Status? { await call(Body(action: "status")) }
    static func pairCode() async -> Code? { await call(Body(action: "pair_code")) }
    static func unlink(_ id: String) async { let _: Ok? = await call(Body(action: "unlink", device_id: id)) }
    static func ask(_ text: String) async -> String? { (await call(Body(action: "ask", text: text)) as Asked?)?.task_id }
    static func tasks() async -> [NavigatorTask] { (await call(Body(action: "tasks")) as Tasks?)?.tasks ?? [] }
    static func stop(_ id: String) async { let _: Ok? = await call(Body(action: "stop", task_id: id)) }
}

// MARK: - The screen (Roger's Mac design, Oct 19: night look, live status card, Stop)

/// Navigator's own colors: always the night look, on the iPhone and the Mac (like Discovery).
private enum NavStyle {
    static let top = Color(red: 0.106, green: 0.165, blue: 0.361)      // #1B2A5C
    static let bottom = Color(red: 0.039, green: 0.078, blue: 0.188)   // #0A1430
    static let card = Color(red: 0.075, green: 0.118, blue: 0.267)     // #131E44
    static let card2 = Color(red: 0.102, green: 0.157, blue: 0.337)    // #1A2856
    static let stroke = Color(red: 0.165, green: 0.227, blue: 0.431)   // #2A3A6E
    static let text = Color(red: 0.949, green: 0.957, blue: 0.980)     // #F2F4FA
    static let soft = Color(red: 0.663, green: 0.702, blue: 0.800)     // #A9B3CC
    static let gold = Color(red: 0.910, green: 0.753, blue: 0.416)     // #E8C06A
    static let green = Color(red: 0.561, green: 0.827, blue: 0.659)    // #8FD3A8
    static let red = Color(red: 0.898, green: 0.282, blue: 0.302)      // #E5484D
    static let ink = Color(red: 0.039, green: 0.078, blue: 0.188)
}

struct NavigatorView: View {
    @State private var macs: [NavigatorMacInfo] = []
    @State private var tasks: [NavigatorTask] = []
    @State private var code: String?
    @State private var draft = ""
    @State private var sending = false
    @State private var problem: String?
    @State private var loaded = false
    @State private var openRecords: Set<String> = []
    @FocusState private var askFocused: Bool

    private let examples = ["Find my car insurance PDF", "Find images from last week", "Where's my lease?"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                macCard
                askCard
                ForEach(tasks) { task in
                    if task.isActive {
                        statusCard(task)
                    } else {
                        resultCard(task)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(NavStyle.text)
        .background(
            LinearGradient(colors: [NavStyle.top, NavStyle.bottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .environment(\.colorScheme, .dark)
        .navigationTitle("Navigator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NavStyle.top, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await refresh() }
        .task {
            // Keep it live: quick while something is being worked on, slower otherwise.
            while !Task.isCancelled {
                let busy = tasks.contains(where: \.isActive) || code != nil
                try? await Task.sleep(for: .seconds(busy ? 1.5 : 6))
                await refresh()
            }
        }
        .refreshable { await refresh() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "safari")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(NavStyle.gold)
                .accessibilityHidden(true)
            Text("Navigator")
                .font(.system(size: 30, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Looks only")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NavStyle.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(NavStyle.green))
                .accessibilityLabel("Looks only. It never moves, changes, sends or deletes anything.")
            Spacer(minLength: 0)
        }
    }

    // MARK: Your Mac

    private var macCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if macs.isEmpty && loaded {
                Text("No Mac linked yet.")
                    .foregroundStyle(NavStyle.soft)
            }
            ForEach(macs) { mac in
                let ready = isFresh(mac.last_seen)
                HStack(spacing: 10) {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(NavStyle.gold)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mac.name).font(.headline)
                        HStack(spacing: 6) {
                            Circle().fill(ready ? NavStyle.green : NavStyle.soft).frame(width: 8, height: 8)
                            Text(ready ? "Ready" : "Asleep or offline. Navigator waits until it's back.")
                                .font(.footnote)
                                .foregroundStyle(NavStyle.soft)
                        }
                    }
                    Spacer()
                    Button("Unlink", role: .destructive) {
                        Task { await NavigatorService.unlink(mac.id); await refresh() }
                    }
                    .buttonStyle(.borderless)
                    .font(.footnote)
                }
                .accessibilityElement(children: .combine)
            }
            if let code {
                VStack(alignment: .leading, spacing: 6) {
                    Text(code)
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityLabel("Code: \(code.map { String($0) }.joined(separator: " "))")
                    Text("Type this in Navigator on your Mac (the star in the menu bar). It works for 10 minutes, once.")
                        .font(.footnote)
                        .foregroundStyle(NavStyle.soft)
                }
            }
            if macs.isEmpty || code != nil {
                Button {
                    Task {
                        code = await NavigatorService.pairCode()?.code
                        if code == nil { problem = "Couldn't make a code. Please try again." }
                    }
                } label: {
                    Label(code == nil ? "Link a Mac" : "Make a new code", systemImage: "link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NavStyle.gold)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task {
                        code = await NavigatorService.pairCode()?.code
                        if code == nil { problem = "Couldn't make a code. Please try again." }
                    }
                } label: {
                    Label("Link another Mac", systemImage: "link")
                        .font(.footnote)
                        .foregroundStyle(NavStyle.soft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card())
    }

    // MARK: Ask

    private var askCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("What should Navigator find?", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($askFocused)
                    .submitLabel(.send)
                    .onSubmit { Task { await send() } }
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                Button {
                    Task { await send() }
                } label: {
                    Group {
                        if sending { ProgressView().tint(NavStyle.ink) } else { Text("Find").font(.headline) }
                    }
                    .foregroundStyle(NavStyle.ink)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.gold))
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending || macs.isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || macs.isEmpty ? 0.5 : 1)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NavStyle.card2))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { e in
                        Button { draft = e } label: {
                            Text(e)
                                .font(.footnote)
                                .foregroundStyle(NavStyle.text)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 34)
                                .background(Capsule().strokeBorder(NavStyle.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let problem {
                Text(problem).foregroundStyle(NavStyle.red).font(.footnote)
            }
            Text(macs.isEmpty ? "Link a Mac first." : "Your Mac looks only in the folders it's allowed to (Desktop, Documents and Downloads to start).")
                .font(.footnote)
                .foregroundStyle(NavStyle.soft)
        }
        .padding(16)
        .background(card())
    }

    // MARK: Working on it (live)

    private func statusCard(_ task: NavigatorTask) -> some View {
        let events = task.events ?? []
        let kinds = Set(events.map(\.kind))
        let mac = events.first(where: { $0.kind == "picked_up" })?.detail?.mac ?? macs.first?.name ?? "your Mac"
        let folders = events.first(where: { $0.kind == "searching" })?.detail?.folders ?? []
        let steps: [(String, Bool)] = [
            (task.status == "queued" && !kinds.contains("picked_up") ? "Waiting for your Mac" : "Your Mac picked it up", kinds.contains("picked_up")),
            ("Made a plan (look only)", kinds.contains("planned")),
            (folders.isEmpty ? "Searching your folders" : "Searching \(folders.joined(separator: ", "))", kinds.contains("done")),
            ("Show you what it found", false),
        ]
        let doneCount = steps.filter(\.1).count
        let current = steps.firstIndex(where: { !$0.1 }) ?? steps.count - 1

        return VStack(alignment: .leading, spacing: 14) {
            Text("\u{201C}\(task.request)\u{201D}")
                .font(.subheadline)
                .foregroundStyle(NavStyle.soft)
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(NavStyle.gold.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: "safari").foregroundStyle(NavStyle.gold)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Navigator is working on it").font(.headline)
                    Text("On \(mac)").font(.footnote).foregroundStyle(NavStyle.soft)
                }
                Spacer()
                Text("Step \(min(current + 1, steps.count)) of \(steps.count)")
                    .font(.footnote)
                    .foregroundStyle(NavStyle.soft)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 10) {
                        if step.1 {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NavStyle.green)
                                .frame(width: 16)
                        } else if i == current {
                            ProgressView().controlSize(.small).tint(NavStyle.gold).frame(width: 16)
                        } else {
                            Circle().strokeBorder(NavStyle.stroke, lineWidth: 2).frame(width: 14, height: 14).frame(width: 16)
                        }
                        Text(step.0)
                            .font(.subheadline.weight(i == current ? .semibold : .regular))
                            .foregroundStyle(step.1 || i == current ? NavStyle.text : NavStyle.soft)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            ProgressView(value: Double(doneCount) + 0.5, total: Double(steps.count))
                .tint(NavStyle.gold)
                .accessibilityLabel("Progress")
            Button {
                Task { await NavigatorService.stop(task.id); await refresh() }
            } label: {
                Text("Stop")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.red))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Stops this search right away")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NavStyle.card)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NavStyle.gold, lineWidth: 1))
        )
    }

    // MARK: Results

    private func resultCard(_ task: NavigatorTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\u{201C}\(task.request)\u{201D}")
                .font(.subheadline)
                .foregroundStyle(NavStyle.soft)
            switch task.status {
            case "failed":
                Text(task.error ?? "Something went wrong.").foregroundStyle(NavStyle.red)
            case "stopped":
                Text("Stopped. Nothing was changed.").foregroundStyle(NavStyle.soft)
            default:
                let files = task.result?.files ?? []
                let searched = (task.result?.searched ?? []).joined(separator: ", ")
                if files.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nothing found\(searched.isEmpty ? "" : " in \(searched)").")
                            .font(.headline)
                        Text(tryInstead(task.request))
                            .font(.subheadline)
                            .foregroundStyle(NavStyle.soft)
                    }
                } else {
                    Text("FOUND \(files.count)")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(NavStyle.soft)
                    ForEach(files, id: \.self) { f in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: f.kind))
                                .font(.title3)
                                .foregroundStyle(NavStyle.gold)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name).font(.body.weight(.semibold)).lineLimit(2)
                                Text([f.folder, shortDate(f.modified).map { "changed \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.footnote)
                                    .foregroundStyle(NavStyle.soft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.card2))
                        .accessibilityElement(children: .combine)
                    }
                    Text("To open one, click it in Navigator on your Mac (the star in the menu bar).")
                        .font(.footnote)
                        .foregroundStyle(NavStyle.soft)
                }
            }
            if let events = task.events, !events.isEmpty {
                recordView(task.id, events)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card())
    }

    /// "What Navigator did": every step, with the time.
    private func recordView(_ id: String, _ events: [NavigatorEvent]) -> some View {
        let open = openRecords.contains(id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if open { openRecords.remove(id) } else { openRecords.insert(id) }
                }
            } label: {
                HStack {
                    Text("What Navigator did").font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.footnote)
                }
                .foregroundStyle(NavStyle.text)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                ForEach(Array(events.enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(e.time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(NavStyle.soft)
                            .frame(minWidth: 80, alignment: .leading)
                        Text(e.words).font(.footnote)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: Helpers

    private func card() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(NavStyle.card)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NavStyle.stroke, lineWidth: 1))
    }

    private func icon(for kind: String?) -> String {
        switch kind {
        case "image": return "photo"
        case "pdf", "document": return "doc.text"
        case "spreadsheet": return "tablecells"
        case "presentation": return "rectangle.on.rectangle"
        case "video": return "film"
        case "audio": return "waveform"
        default: return "doc"
        }
    }

    /// When nothing turns up: suggest one key word to try.
    private func tryInstead(_ request: String) -> String {
        let skip: Set<String> = ["find", "my", "the", "a", "an", "where", "where's", "wheres", "is", "from", "last", "week",
                                 "for", "of", "in", "on", "pdf", "file", "files", "me", "please", "show", "get", "and"]
        let words = request.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { $0.count > 2 && !skip.contains($0) }
        if let word = words.max(by: { $0.count < $1.count }) {
            return "Try one word, like \u{201C}\(word)\u{201D}, or a word from the file's name."
        }
        return "Try a word from the file's name."
    }

    private func isFresh(_ iso: String?) -> Bool {
        guard let iso else { return false }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return false }
        return Date().timeIntervalSince(d) < 90
    }

    private func shortDate(_ iso: String?) -> String? {
        guard let iso, let d = ISO8601DateFormatter().date(from: iso) else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }

    private func refresh() async {
        if let s = await NavigatorService.status() {
            let before = macs.count
            macs = s.macs ?? []
            // A new Mac just linked: the code has done its job.
            if loaded && macs.count > before { code = nil }
        }
        tasks = await NavigatorService.tasks()
        loaded = true
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        sending = true
        problem = nil
        askFocused = false
        if await NavigatorService.ask(text) != nil {
            draft = ""
            await refresh()
        } else {
            problem = "Couldn't send that to your Mac. Please try again."
        }
        sending = false
    }
}
