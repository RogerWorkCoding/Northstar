import SwiftUI
import Supabase

// 🧭 Northstar Navigator (owner preview). Level 1: find files. Level 2: read ONE file you OK and answer
// from it. Level 3: drafts you approve (an email opened in Mail on your Mac, or an event / reminder added
// here when you tap Add). It never sends, moves, deletes or buys. See docs/navigator-levels-2-3.md.
// Shown only when the brain says this account is an owner (NS_ADMIN_USERS).

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
        let file: String?
        let what: String?
        let place: String?
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
        case "planned": return "Plan: \(detail?.plan?.say ?? "search your folders")"
        case "searching": return "Searched: \((detail?.folders ?? []).joined(separator: ", "))"
        case "done":
            var s = "Found \(detail?.found ?? 0). Changed nothing."
            if let n = detail?.skipped_protected, n > 0 { s += " Skipped \(n) in protected places." }
            return s
        case "found": return "Found \(detail?.found ?? 0). Waiting for your OK."
        case "approved": return "You OK'd: \(detail?.what ?? "go ahead")\(detail?.file.map { " (\($0))" } ?? "")"
        case "continuing": return "\(detail?.mac ?? "Your Mac") picked it up again"
        case "reading": return "Read: \(detail?.file ?? "the file you picked")"
        case "answered": return "Wrote your answer from that file. The file's text wasn't kept."
        case "draft_opened": return "Opened the draft in Mail on your Mac. Not sent: you send it."
        case "added": return "You added it to \(detail?.place ?? "your calendar")"
        case "cancelled": return "You said no. Nothing was added."
        case "stopped": return "You stopped it. Nothing was changed."
        case "stopped_on_mac": return "Stopped on your Mac. Nothing was changed."
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
        let answer: String?
        let file: String?
        let note: String?
        let opened: Bool?
        let outcome: String?
        let place: String?
    }
    nonisolated struct Plan: Decodable, Hashable, Sendable {
        nonisolated struct Email: Decodable, Hashable, Sendable {
            let to: String?
            let subject: String?
            let body: String?
            let attach: Bool?
        }
        let intent: String?
        let say: String?
        let question: String?
        let email: Email?
        let schedule: NorthstarInsight.Schedule?
    }
    nonisolated struct Choice: Decodable, Hashable, Sendable {
        let index: Int?
        let name: String?
    }
    let id: String
    let request: String
    let status: String
    let created_at: String
    let plan: Plan?
    let choice: Choice?
    let result: Result?
    let error: String?
    let events: [NavigatorEvent]?

    var isActive: Bool { status == "queued" || status == "running" || status == "approved" }
    var intent: String { plan?.intent ?? "find" }
}

@MainActor
enum NavigatorService {
    nonisolated private struct Body: Encodable, Sendable {
        let action: String
        var text: String? = nil
        var task_id: String? = nil
        var device_id: String? = nil
        var today: String? = nil
        var time: String? = nil
        var tz: String? = nil
        var file_index: Int? = nil
        var outcome: String? = nil
        var place: String? = nil
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
    static func ask(_ text: String) async -> String? {
        let now = Date()
        let day = DateFormatter(), clock = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "yyyy-MM-dd"
        clock.locale = Locale(identifier: "en_US_POSIX"); clock.dateFormat = "HH:mm"
        let body = Body(action: "ask", text: text, today: day.string(from: now), time: clock.string(from: now),
                        tz: TimeZone.current.identifier)
        return (await call(body) as Asked?)?.task_id
    }
    /// The person's OK: read this file, or open the email draft with this attachment (nil = none).
    static func approve(_ id: String, fileIndex: Int?) async -> Bool {
        (await call(Body(action: "approve", task_id: id, file_index: fileIndex)) as Ok?)?.ok == true
    }
    /// Event / reminder drafts: added on this iPhone, or the person said no.
    static func finish(_ id: String, added: Bool, where place: String?) async {
        let _: Ok? = await call(Body(action: "finish", task_id: id, outcome: added ? "added" : "cancelled", place: place))
    }
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
    /// Which file the person picked on an OK card (task id → index; -1 = no attachment).
    @State private var picks: [String: Int] = [:]
    @State private var busyTask: String?
    @FocusState private var askFocused: Bool

    private let examples = ["Find my car insurance PDF", "What does my lease say about pets?",
                            "Email my insurance card to Sam", "Remind me to renew my registration Friday"]

    @State private var width: CGFloat = 0
    /// Wide window (the Mac): the status panel sits on the right, like the Mac design.
    private var wide: Bool { width >= 900 }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    macCard
                    askCard
                    ForEach(tasks) { task in
                        if task.isActive {
                            statusCard(task)
                        } else if task.status == "needs_ok" {
                            okCard(task)
                        } else {
                            resultCard(task)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            if wide {
                ScrollView { statusPanel.padding(20) }
                    .frame(width: 320)
                    .background(NavStyle.bottom.opacity(0.55))
                    .overlay(alignment: .leading) { Rectangle().fill(NavStyle.stroke).frame(width: 1) }
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
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

    // MARK: Status panel (right side, wide windows)

    /// What's happening right now, and the latest steps across all requests, stops included.
    private var statusPanel: some View {
        let active = tasks.first(where: { $0.isActive })
        let waiting = tasks.first(where: { $0.status == "needs_ok" })
        let feed = tasks
            .flatMap { t in (t.events ?? []).map { (task: t, event: $0) } }
            .sorted { $0.event.at > $1.event.at }
            .prefix(14)
        return VStack(alignment: .leading, spacing: 16) {
            Text("Status").font(.headline)

            // Right now
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(active != nil ? NavStyle.gold : waiting != nil ? NavStyle.gold.opacity(0.6) : NavStyle.green)
                        .frame(width: 9, height: 9)
                    Text(active != nil ? "Working on it" : waiting != nil ? "Waiting for your OK" : "Ready. Nothing running.")
                        .font(.subheadline.weight(.semibold))
                }
                if let t = active ?? waiting {
                    Text("\u{201C}\(t.request)\u{201D}")
                        .font(.footnote)
                        .foregroundStyle(NavStyle.soft)
                        .lineLimit(3)
                }
                if let t = active {
                    Button {
                        Task { await NavigatorService.stop(t.id); await refresh() }
                    } label: {
                        Text("Stop")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NavStyle.red))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Stops this right away. Nothing is changed.")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(card())

            // Recent activity
            Text("RECENT ACTIVITY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(NavStyle.soft)
            if feed.isEmpty {
                Text("Nothing yet. Ask Navigator to find, read or draft something.")
                    .font(.footnote)
                    .foregroundStyle(NavStyle.soft)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(feed.enumerated()), id: \.offset) { _, item in
                    let stop = item.event.kind == "stopped" || item.event.kind == "stopped_on_mac" || item.event.kind == "cancelled"
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: stop ? "hand.raised" : "circle.fill")
                            .font(.system(size: stop ? 12 : 5))
                            .foregroundStyle(stop ? NavStyle.text : NavStyle.soft)
                            .frame(width: 14)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.event.words)
                                .font(.footnote.weight(stop ? .semibold : .regular))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(item.event.time) · \u{201C}\(item.task.request)\u{201D}")
                                .font(.caption2)
                                .foregroundStyle(NavStyle.soft)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Every step is kept in your record, on your Mac and in Northstar.")
                .font(.caption)
                .foregroundStyle(NavStyle.soft)
        }
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
            Text("Asks first")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NavStyle.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(NavStyle.green))
                .accessibilityLabel("Asks first. It asks before reading a file or making a draft, and never sends, moves or deletes anything.")
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
                TextField("Find, read or draft\u{2026}", text: $draft, axis: .vertical)
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
                        if sending { ProgressView().tint(NavStyle.ink) } else { Text("Ask").font(.headline) }
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
            Text(macs.isEmpty ? "Link a Mac first." : "Navigator finds files, reads one you OK, and drafts emails, events and reminders for you to approve. It never sends, moves or deletes anything. Your Mac looks only in Desktop, Documents and Downloads.")
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
        let searching = folders.isEmpty ? "Searching your folders" : "Searching \(folders.joined(separator: ", "))"
        let picked = (task.status == "queued" && !kinds.contains("picked_up")) ? "Waiting for your Mac" : "Your Mac picked it up"
        let file = task.choice?.name ?? "the file"
        let steps: [(String, Bool)]
        switch (task.intent, task.choice != nil) {
        case ("read", true):
            steps = [("You OK'd reading \(file)", true), ("Reading it on your Mac", kinds.contains("reading")),
                     ("Writing your answer", kinds.contains("answered"))]
        case ("email", true):
            steps = [("You OK'd the draft", true), ("Opening it in Mail on your Mac", kinds.contains("draft_opened"))]
        case ("read", false), ("email", false):
            steps = [(picked, kinds.contains("picked_up")), (searching, kinds.contains("found")),
                     ("Ask you before going further", false)]
        default:
            steps = [(picked, kinds.contains("picked_up")), ("Made a plan", kinds.contains("planned")),
                     (searching, kinds.contains("done")), ("Show you what it found", false)]
        }
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
                Text(task.result?.outcome == "cancelled" ? "You said no. Nothing was added." : "Stopped. Nothing was changed.")
                    .foregroundStyle(NavStyle.soft)
            case "done" where task.intent == "unsupported":
                Text(task.result?.note ?? "Navigator can't do that yet.")
                    .font(.body)
            case "done" where task.intent == "read":
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.result?.answer ?? "")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if let f = task.result?.file {
                        Label("From \(f)", systemImage: "doc.text")
                            .font(.footnote)
                            .foregroundStyle(NavStyle.soft)
                    }
                    Text("AI answers can be wrong. Check the file for anything important.")
                        .font(.caption)
                        .foregroundStyle(NavStyle.soft)
                }
            case "done" where task.intent == "email":
                VStack(alignment: .leading, spacing: 6) {
                    Label("The draft is open in Mail on your Mac.", systemImage: "envelope.open")
                        .font(.headline)
                    Text("Check it and press Send there. Navigator didn't send anything.")
                        .font(.subheadline)
                        .foregroundStyle(NavStyle.soft)
                    if let f = task.choice?.name {
                        Label("Attached: \(f)", systemImage: "paperclip").font(.footnote).foregroundStyle(NavStyle.soft)
                    }
                }
            case "done" where task.intent == "event" || task.intent == "reminder":
                Label("Added to \(task.result?.place ?? (task.intent == "event" ? "Calendar" : "Reminders"))", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(NavStyle.green)
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

    // MARK: Waiting for your OK (Levels 2 and 3)

    @ViewBuilder
    private func okCard(_ task: NavigatorTask) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised").foregroundStyle(NavStyle.gold).accessibilityHidden(true)
                Text("Needs your OK").font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(NavStyle.gold)
            }
            Text("\u{201C}\(task.request)\u{201D}")
                .font(.subheadline)
                .foregroundStyle(NavStyle.soft)
            switch task.intent {
            case "read": readOK(task)
            case "email": emailOK(task)
            default: scheduleOK(task)
            }
            if let events = task.events, !events.isEmpty {
                recordView(task.id, events)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NavStyle.card)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NavStyle.gold, lineWidth: 1))
        )
    }

    /// Level 2: "Read this file to answer?" The file's text goes to Northstar's brain only after this OK.
    @ViewBuilder
    private func readOK(_ task: NavigatorTask) -> some View {
        let files = task.result?.files ?? []
        if files.isEmpty {
            Text("Nothing found to read.").font(.headline)
            Text(tryInstead(task.request)).font(.subheadline).foregroundStyle(NavStyle.soft)
            secondaryButton("OK") { await NavigatorService.stop(task.id) }
        } else {
            Text("Read this file to answer?").font(.headline)
            filePicker(task, files, allowNone: false)
            Text("Your Mac reads just this file and sends its text to Northstar's brain to write the answer. The text isn't kept.")
                .font(.footnote)
                .foregroundStyle(NavStyle.soft)
            HStack(spacing: 10) {
                primaryButton("Read it", busy: busyTask != nil) {
                    _ = await NavigatorService.approve(task.id, fileIndex: picks[task.id] ?? 0)
                }
                secondaryButton("No thanks") { await NavigatorService.stop(task.id) }
            }
        }
    }

    /// Level 3: an email draft. Mail opens on the Mac with it; the person presses Send.
    @ViewBuilder
    private func emailOK(_ task: NavigatorTask) -> some View {
        let e = task.plan?.email
        let files = task.result?.files ?? []
        VStack(alignment: .leading, spacing: 6) {
            draftLine("To", (e?.to ?? "").isEmpty ? "You'll add it in Mail" : e?.to ?? "")
            draftLine("Subject", e?.subject ?? "")
            Text(e?.body ?? "")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.card2))
        }
        if e?.attach == true {
            Text(files.isEmpty ? "No file found to attach. You can add one in Mail." : "Attach which file?")
                .font(.subheadline.weight(.semibold))
            if !files.isEmpty { filePicker(task, files, allowNone: true) }
        }
        Text("Mail opens on your Mac with this draft. Navigator never sends it: you press Send.")
            .font(.footnote)
            .foregroundStyle(NavStyle.soft)
        HStack(spacing: 10) {
            primaryButton("Put it in Mail on my Mac", busy: busyTask != nil) {
                let pick = picks[task.id] ?? (files.isEmpty || e?.attach != true ? -1 : 0)
                _ = await NavigatorService.approve(task.id, fileIndex: pick < 0 ? nil : pick)
            }
            secondaryButton("Cancel") { await NavigatorService.stop(task.id) }
        }
    }

    /// Level 3: an event or reminder, added on this iPhone (or this Mac) when the person taps Add.
    @ViewBuilder
    private func scheduleOK(_ task: NavigatorTask) -> some View {
        if let sc = task.plan?.schedule {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: sc.isEvent ? "calendar" : "checklist")
                    .font(.title2)
                    .foregroundStyle(NavStyle.gold)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sc.title).font(.headline)
                    Text(sc.whenText).font(.subheadline)
                    if let loc = sc.location, !loc.isEmpty {
                        Text(loc).font(.footnote).foregroundStyle(NavStyle.soft)
                    }
                    if let r = sc.repeatRule { Text("Repeats \(r)").font(.footnote).foregroundStyle(NavStyle.soft) }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.card2))
            HStack(spacing: 10) {
                primaryButton(sc.isEvent ? "Add to Calendar" : "Add to Reminders", busy: busyTask != nil) {
                    do {
                        let place = try await NorthstarCalendar.shared.add(sc)
                        await NavigatorService.finish(task.id, added: true, where: place)
                    } catch {
                        problem = error.localizedDescription
                    }
                }
                secondaryButton("No thanks") { await NavigatorService.finish(task.id, added: false, where: nil) }
            }
        } else {
            Text("This draft is missing its details. Please ask again.").foregroundStyle(NavStyle.soft)
            secondaryButton("OK") { await NavigatorService.stop(task.id) }
        }
    }

    /// The files to choose from (the best few the Mac found). Tap one to pick it.
    private func filePicker(_ task: NavigatorTask, _ files: [NavigatorFile], allowNone: Bool) -> some View {
        let picked = picks[task.id] ?? 0
        return VStack(spacing: 8) {
            ForEach(Array(files.enumerated()), id: \.offset) { i, f in
                Button { picks[task.id] = i } label: {
                    HStack(spacing: 12) {
                        Image(systemName: picked == i ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(picked == i ? NavStyle.gold : NavStyle.soft)
                        Image(systemName: icon(for: f.kind)).foregroundStyle(NavStyle.gold).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                            Text([f.folder, shortDate(f.modified).map { "changed \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(NavStyle.soft)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(NavStyle.text)
                    .padding(10)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(picked == i ? NavStyle.card2 : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked == i ? .isSelected : [])
            }
            if allowNone {
                Button { picks[task.id] = -1 } label: {
                    HStack(spacing: 12) {
                        Image(systemName: picked == -1 ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(picked == -1 ? NavStyle.gold : NavStyle.soft)
                        Text("No attachment").font(.subheadline)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(NavStyle.text)
                    .padding(10)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked == -1 ? .isSelected : [])
            }
        }
    }

    private func draftLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(NavStyle.soft).frame(width: 60, alignment: .leading)
            Text(value).font(.subheadline)
        }
    }

    private func primaryButton(_ title: String, busy: Bool, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await act(action) }
        } label: {
            Group {
                if busy { ProgressView().tint(NavStyle.ink) } else { Text(title).font(.headline) }
            }
            .foregroundStyle(NavStyle.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.gold))
        }
        .buttonStyle(.plain)
        .disabled(busyTask != nil)
    }

    private func secondaryButton(_ title: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await act(action) }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(NavStyle.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NavStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(busyTask != nil)
    }

    /// Runs one button's work, then refreshes the list.
    private func act(_ work: @MainActor () async -> Void) async {
        guard busyTask == nil else { return }
        busyTask = "busy"
        problem = nil
        await work()
        await refresh()
        busyTask = nil
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
