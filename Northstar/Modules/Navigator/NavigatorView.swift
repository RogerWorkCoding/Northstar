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
    /// Copies of an image: a small preview (JPEG, base64), and "exact" or "near".
    let thumb: String?
    let match: String?

    var preview: UIImage? { thumb.flatMap { Data(base64Encoded: $0) }.flatMap { UIImage(data: $0) } }

    nonisolated struct Reference: Decodable, Hashable, Sendable {
        let name: String
        let folder: String?
        let thumb: String?
        var preview: UIImage? { thumb.flatMap { Data(base64Encoded: $0) }.flatMap { UIImage(data: $0) } }
    }
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
        let auto: Bool?
        let kind: String?
        let always_allow: Bool?
        let how: String?
        let count: Int?
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
        case "approved":
            let what = "\(detail?.what ?? "go ahead")\(detail?.file.map { " (\($0))" } ?? "")"
            return detail?.auto == true ? "Went ahead (Always allow is on): \(what)" : "You OK'd: \(what)"
        case "comparing": return "Compared your image with the images in \((detail?.folders ?? []).joined(separator: ", "))"
        case "trashed": return "Moved \(detail?.count ?? 0) to the Trash. The Trash was not emptied."
        case "undone": return "Put back \(detail?.count ?? 0) from the Trash (Undo)"
        case "trashing": return "Moving to the Trash\u{2026}"
        case "opened":
            return detail?.how == "reveal" ? "Showed \(detail?.file ?? "the file") in Finder" : "Opened \(detail?.file ?? "the file") on your Mac"
        case "permission_changed":
            return "You turned \(detail?.always_allow == true ? "on" : "off") Always allow: \(NavigatorView.permissionTitle(detail?.kind ?? ""))"
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
        let reference: NavigatorFile.Reference?
        let checked: Int?
        let moved: [String]?
        let undone: Bool?
        let put_back: [String]?
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
        let how: String?
        let names: [String]?
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
        var kind: String? = nil
        var on: Bool? = nil
        var auto: Bool? = nil
        var how: String? = nil
        var file_indexes: [Int]? = nil
    }
    nonisolated struct Always: Decodable, Sendable { let always: [String: Bool]? }
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
    static func finish(_ id: String, added: Bool, where place: String?, auto: Bool = false) async {
        let _: Ok? = await call(Body(action: "finish", task_id: id, outcome: added ? "added" : "cancelled", place: place,
                                     auto: auto ? true : nil))
    }
    /// Open a found file on the Mac, or show it in Finder. The tap is the OK.
    static func openFile(_ taskId: String, index: Int, reveal: Bool) async -> Bool {
        (await call(Body(action: "open_file", task_id: taskId, file_index: index, how: reveal ? "reveal" : "open")) as Ok?)?.ok == true
    }
    /// Find copies of an image Navigator found (the Mac compares; nothing is changed).
    static func findCopies(_ taskId: String, index: Int) async -> Bool {
        (await call(Body(action: "find_copies", task_id: taskId, file_index: index)) as Ok?)?.ok == true
    }
    /// Move the ticked copies to the Trash (never emptied).
    static func approveTrash(_ taskId: String, indexes: [Int]) async -> Bool {
        (await call(Body(action: "approve", task_id: taskId, file_indexes: indexes)) as Ok?)?.ok == true
    }
    /// Undo: put them back where they were.
    static func undo(_ taskId: String) async -> Bool {
        (await call(Body(action: "undo", task_id: taskId)) as Ok?)?.ok == true
    }
    /// "Always allow" switches (all off at first).
    static func permissions() async -> [String: Bool] { (await call(Body(action: "permissions")) as Always?)?.always ?? [:] }
    static func setPermission(_ kind: String, on: Bool) async -> [String: Bool]? {
        (await call(Body(action: "set_permission", kind: kind, on: on)) as Always?)?.always
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
    /// "Always allow" switches, from the brain. Off unless turned on.
    @State private var always: [String: Bool] = [:]
    @State private var autoTried: Set<String> = []
    /// "Why?" reasons the person opened (task id or row id).
    @State private var openReasons: Set<String> = []
    /// Copies ticked for the Trash (task id → indexes).
    @State private var trashPicks: [String: Set<Int>] = [:]
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
                    ForEach(tasks.filter { ($0.intent != "open" && $0.intent != "undo") || $0.isActive || $0.status == "failed" }) { task in
                        if task.isActive {
                            statusCard(task)
                        } else if task.status == "needs_ok" {
                            okCard(task)
                        } else {
                            resultCard(task)
                        }
                    }
                    if !wide && width > 0 {
                        statusPanel
                            .padding(16)
                            .background(card())
                    }
                }
                .padding(20)
                .frame(maxWidth: wide ? 1000 : 760)
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

    // MARK: Reasons (why Navigator asks, why something stopped)

    nonisolated static func permissionTitle(_ kind: String) -> String {
        switch kind {
        case "read": return "Read a file to answer"
        case "email": return "Open email drafts in Mail"
        case "event": return "Add calendar events"
        case "reminder": return "Add reminders"
        default: return kind
        }
    }

    /// The "Always allow" switches: off = Navigator asks every time; on = it goes ahead and records it.
    private var alwaysAllowSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ALWAYS ALLOW")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(NavStyle.soft)
            ForEach(["read", "email", "event", "reminder"], id: \.self) { kind in
                Toggle(isOn: Binding(
                    get: { always[kind] == true },
                    set: { on in
                        always[kind] = on
                        Task {
                            if let saved = await NavigatorService.setPermission(kind, on: on) { always = saved }
                            await refresh()
                        }
                    }
                )) {
                    Text(Self.permissionTitle(kind)).font(.footnote)
                }
                .tint(NavStyle.gold)
            }
            Text("Off: Navigator asks you every time. On: it goes ahead, and still writes it in the history. Sending, deleting and moving always need you.")
                .font(.caption)
                .foregroundStyle(NavStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(card())
    }

    /// Why Navigator needs this permission, in plain words. Shown behind "Why?".
    static func reason(for intent: String) -> String {
        switch intent {
        case "read":
            return "To answer your question, Navigator has to read this one file. Your Mac reads it and sends the text to Northstar's brain once to write the answer. The text isn't kept, and no other file is read."
        case "email":
            return "You asked for an email. Navigator wrote a draft and wants to open it in Mail on your Mac, with the file you picked. It never sends it: you check it and press Send yourself."
        case "duplicates":
            return "You asked to remove copies of this image. Only the copies you tick go to the Trash, one at a time, and the Trash is never emptied. You can Undo here, or use Put Back in the Trash. This always asks, even with Always allow on."
        case "event":
            return "You asked for a calendar event. Navigator only adds it to your Calendar after you allow it, and you can change or delete it there anytime."
        case "reminder":
            return "You asked for a reminder. Navigator only adds it to your Reminders after you allow it, and you can change or delete it there anytime."
        default:
            return "Navigator asks before doing anything that reads, adds or opens something for you."
        }
    }

    /// The hidden reason: tap "Why?" to show it.
    private func whyRow(_ id: String, _ reason: String) -> some View {
        let open = openReasons.contains(id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if open { openReasons.remove(id) } else { openReasons.insert(id) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                    Text(open ? "Hide the reason" : "Why is Navigator asking?")
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NavStyle.gold)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(NavStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NavStyle.card2))
            }
        }
    }

    /// One Allow or Decline, for the permissions history.
    private struct PermissionRow: Identifiable {
        let id: String
        let allowed: Bool
        var auto = false
        let what: String
        let request: String
        let time: String
        let at: String
        let reason: String
    }

    private var permissionRows: [PermissionRow] {
        var rows: [PermissionRow] = []
        for t in tasks {
            let events = t.events ?? []
            for (i, e) in events.enumerated() {
                let prev = i > 0 ? events[i - 1].kind : ""
                let id = "\(t.id)-\(i)"
                switch e.kind {
                case "approved" where t.intent == "read" || t.intent == "email" || t.intent == "duplicates":
                    let what = t.intent == "read" ? "Read \(e.detail?.file ?? "a file")"
                        : t.intent == "email" ? "Open the email draft in Mail" : (e.detail?.what.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Move to the Trash")
                    rows.append(PermissionRow(id: id, allowed: true, auto: e.detail?.auto == true, what: what, request: t.request,
                                              time: e.time, at: e.at, reason: Self.reason(for: t.intent)))
                case "added":
                    rows.append(PermissionRow(id: id, allowed: true, auto: e.detail?.auto == true, what: "Add to \(e.detail?.place ?? "Calendar")",
                                              request: t.request, time: e.time, at: e.at, reason: Self.reason(for: t.intent)))
                case "cancelled":
                    rows.append(PermissionRow(id: id, allowed: false, what: t.intent == "event" ? "Add to Calendar" : "Add to Reminders",
                                              request: t.request, time: e.time, at: e.at, reason: Self.reason(for: t.intent)))
                case "stopped" where prev == "found" || (prev == "planned" && t.intent != "find"):
                    let what = t.intent == "read" ? "Read a file" : t.intent == "email" ? "Open the email draft in Mail"
                        : t.intent == "duplicates" ? "Move copies to the Trash" : "Go ahead"
                    rows.append(PermissionRow(id: id, allowed: false, what: what, request: t.request, time: e.time, at: e.at,
                                              reason: Self.reason(for: t.intent)))
                default: break
                }
            }
        }
        return rows.sorted { $0.at > $1.at }
    }

    /// Why something stopped, in plain words. Every stop has a reason.
    private func stopReason(_ t: NavigatorTask, _ index: Int) -> String {
        let events = t.events ?? []
        let e = events[index]
        let prev = index > 0 ? events[index - 1].kind : ""
        switch e.kind {
        case "cancelled": return "Stopped because you chose Decline. Nothing was added."
        case "stopped_on_mac": return "Stopped because you pressed Stop in the \u{2726} menu on your Mac. Nothing was changed."
        case "failed": return "Stopped because something went wrong: \(e.detail?.error ?? "unknown problem"). Nothing was changed."
        default:
            if prev == "found" || (prev == "planned" && t.intent != "find") {
                return "Stopped because you chose Decline. Nothing was read or opened."
            }
            return "Stopped because you pressed Stop. Nothing was changed."
        }
    }

    // MARK: Status panel (right side, wide windows)

    /// What's happening right now, and the latest steps across all requests, stops included.
    private var statusPanel: some View {
        let active = tasks.first(where: { $0.isActive })
        let waiting = tasks.first(where: { $0.status == "needs_ok" })
        let feed = tasks
            .flatMap { t in (t.events ?? []).enumerated().map { (task: t, index: $0.offset, event: $0.element) } }
            .sorted { $0.event.at > $1.event.at }
            .prefix(14)
        let permissions = permissionRows.prefix(10)
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

            alwaysAllowSection

            // Permissions history: every Allow once and Decline, with the reason behind "Why?"
            Text("PERMISSIONS")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(NavStyle.soft)
            if permissions.isEmpty {
                Text("None yet. Navigator asks before it reads a file, opens a draft or adds to your calendar.")
                    .font(.footnote)
                    .foregroundStyle(NavStyle.soft)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(permissions)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: row.allowed ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.footnote)
                                .foregroundStyle(row.allowed ? NavStyle.green : NavStyle.soft)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(row.allowed ? (row.auto ? "Always allowed" : "Allowed once") : "Declined"): \(row.what)")
                                    .font(.footnote.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(row.time) · \u{201C}\(row.request)\u{201D}")
                                    .font(.caption2)
                                    .foregroundStyle(NavStyle.soft)
                                    .lineLimit(1)
                            }
                        }
                        whyRow(row.id, row.reason)
                            .padding(.leading, 22)
                    }
                }
            }

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
                    let stop = item.event.kind == "stopped" || item.event.kind == "stopped_on_mac" || item.event.kind == "cancelled" || item.event.kind == "failed"
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: stop ? "hand.raised" : "circle.fill")
                            .font(.system(size: stop ? 12 : 5))
                            .foregroundStyle(stop ? NavStyle.text : NavStyle.soft)
                            .frame(width: 14)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop ? stopReason(item.task, item.index) : item.event.words)
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
        case ("duplicates", false):
            steps = [(picked, kinds.contains("picked_up") || kinds.contains("comparing")),
                     ("Comparing your image with Desktop, Documents and Downloads", kinds.contains("found")),
                     ("Show you the copies first", false)]
        case ("duplicates", true):
            steps = [("You OK'd moving \(task.choice?.names?.count ?? 0) to the Trash", true),
                     ("Moving them one at a time", kinds.contains("trashed"))]
        case ("undo", _):
            steps = [("Putting them back where they were", kinds.contains("undone"))]
        case ("open", _):
            steps = [(task.choice?.how == "reveal" ? "Showing \(file) in Finder" : "Opening \(file) on your Mac", kinds.contains("opened"))]
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
                Label("Stopped because something went wrong: \(task.error ?? "unknown problem"). Nothing was changed.", systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(NavStyle.text)
            case "stopped":
                if let i = (task.events ?? []).lastIndex(where: { ["stopped", "stopped_on_mac", "cancelled"].contains($0.kind) }) {
                    Label(stopReason(task, i), systemImage: "hand.raised")
                        .font(.subheadline)
                        .foregroundStyle(NavStyle.text)
                } else {
                    Text("Stopped. Nothing was changed.").foregroundStyle(NavStyle.soft)
                }
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
            case "done" where task.intent == "duplicates":
                copiesDone(task)
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
                    ForEach(Array(files.enumerated()), id: \.offset) { i, f in
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
                            .accessibilityElement(children: .combine)
                            Spacer(minLength: 0)
                            fileButton(onMac ? "Open" : "Open on Mac", "arrow.up.forward.app") {
                                _ = await NavigatorService.openFile(task.id, index: i, reveal: false)
                            }
                            if f.kind == "image" {
                                fileButton("Find copies", "square.on.square") {
                                    _ = await NavigatorService.findCopies(task.id, index: i)
                                }
                            }
                            if onMac {
                                fileButton("Show in Finder", "folder") {
                                    _ = await NavigatorService.openFile(task.id, index: i, reveal: true)
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NavStyle.card2))
                    }
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
            case "duplicates": copiesOK(task)
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
            Text("Navigator wants to read this file").font(.headline)
            filePicker(task, files, allowNone: false)
            whyRow(task.id, Self.reason(for: "read"))
            HStack(spacing: 10) {
                secondaryButton("Decline") { await NavigatorService.stop(task.id) }
                primaryButton("Allow once", busy: busyTask != nil) {
                    _ = await NavigatorService.approve(task.id, fileIndex: picks[task.id] ?? 0)
                }
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
        Text("Navigator wants to open this draft in Mail on your Mac").font(.subheadline.weight(.semibold))
        whyRow(task.id, Self.reason(for: "email"))
        HStack(spacing: 10) {
            secondaryButton("Decline") { await NavigatorService.stop(task.id) }
            primaryButton("Allow once", busy: busyTask != nil) {
                let pick = picks[task.id] ?? (files.isEmpty || e?.attach != true ? -1 : 0)
                _ = await NavigatorService.approve(task.id, fileIndex: pick < 0 ? nil : pick)
            }
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
            Text(sc.isEvent ? "Navigator wants to add this to your Calendar" : "Navigator wants to add this to your Reminders")
                .font(.subheadline.weight(.semibold))
            whyRow(task.id, Self.reason(for: sc.isEvent ? "event" : "reminder"))
            HStack(spacing: 10) {
                secondaryButton("Decline") { await NavigatorService.finish(task.id, added: false, where: nil) }
                primaryButton("Allow once", busy: busyTask != nil) {
                    do {
                        let place = try await NorthstarCalendar.shared.add(sc)
                        await NavigatorService.finish(task.id, added: true, where: place)
                    } catch {
                        problem = error.localizedDescription
                    }
                }
            }
        } else {
            Text("This draft is missing its details. Please ask again.").foregroundStyle(NavStyle.soft)
            secondaryButton("OK") { await NavigatorService.stop(task.id) }
        }
    }

    /// Copies of an image: shown first, as a grid of images; the person ticks which go to the Trash.
    @ViewBuilder
    private func copiesOK(_ task: NavigatorTask) -> some View {
        let files = task.result?.files ?? []
        let ref = task.result?.reference
        HStack(spacing: 12) {
            thumbView(ref?.preview, size: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your image").font(.caption.weight(.bold)).foregroundStyle(NavStyle.soft)
                Text(ref?.name ?? "").font(.subheadline.weight(.semibold)).lineLimit(2)
                Text("Checked \(task.result?.checked ?? 0) images. Nothing has been changed.")
                    .font(.caption).foregroundStyle(NavStyle.soft)
            }
        }
        if files.isEmpty {
            Text("No copies found.").font(.headline)
            secondaryButton("OK") { await NavigatorService.stop(task.id) }
        } else {
            let picked = trashPicks[task.id] ?? Set(files.indices.filter { files[$0].match == "exact" })
            Text("Found \(files.count). Tick the ones to move to the Trash.").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(Array(files.enumerated()), id: \.offset) { i, f in
                    Button {
                        var p = picked
                        if p.contains(i) { p.remove(i) } else { p.insert(i) }
                        trashPicks[task.id] = p
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                thumbView(f.preview, size: nil)
                                Image(systemName: picked.contains(i) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(picked.contains(i) ? NavStyle.gold : .white)
                                    .shadow(radius: 2)
                                    .padding(6)
                            }
                            Text(f.match == "exact" ? "Exact copy" : "Looks the same")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(f.match == "exact" ? NavStyle.green : NavStyle.gold)
                            Text(f.name).font(.caption.weight(.semibold)).lineLimit(2)
                            Text(f.folder).font(.caption2).foregroundStyle(NavStyle.soft).lineLimit(1)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(picked.contains(i) ? NavStyle.card2 : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(picked.contains(i) ? NavStyle.gold : NavStyle.stroke, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(f.name), \(f.match == "exact" ? "exact copy" : "looks the same"), in \(f.folder)")
                    .accessibilityAddTraits(picked.contains(i) ? .isSelected : [])
                }
            }
            whyRow(task.id, Self.reason(for: "duplicates"))
            HStack(spacing: 10) {
                secondaryButton("Decline") { await NavigatorService.stop(task.id) }
                primaryButton(picked.isEmpty ? "Tick some first" : "Move \(picked.count) to Trash (Allow once)", busy: busyTask != nil) {
                    guard !picked.isEmpty else { return }
                    _ = await NavigatorService.approveTrash(task.id, indexes: picked.sorted())
                }
            }
        }
    }

    /// After the move: what went to the Trash, and Undo.
    @ViewBuilder
    private func copiesDone(_ task: NavigatorTask) -> some View {
        let moved = task.result?.moved ?? []
        if task.result?.undone == true {
            Label("Put back. Everything is where it was.", systemImage: "arrow.uturn.backward.circle")
                .font(.headline)
                .foregroundStyle(NavStyle.green)
        } else {
            Label("Moved \(moved.count) to the Trash", systemImage: "trash")
                .font(.headline)
            ForEach(moved, id: \.self) { name in
                Text(name).font(.footnote).foregroundStyle(NavStyle.soft)
            }
            Text("The Trash was not emptied. You can Undo, or use Put Back in the Trash.")
                .font(.caption)
                .foregroundStyle(NavStyle.soft)
            if !moved.isEmpty {
                secondaryButton("Undo: put them back") { _ = await NavigatorService.undo(task.id) }
            }
        }
    }

    private func thumbView(_ image: UIImage?, size: CGFloat?) -> some View {
        Color.clear
            .frame(width: size, height: size ?? 120)
            .frame(maxWidth: size == nil ? .infinity : nil)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        NavStyle.card2
                        Image(systemName: "photo").foregroundStyle(NavStyle.soft)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
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

    /// Running on the Mac itself (the iPhone app in a Mac window): "Open" happens right here.
    private var onMac: Bool { ProcessInfo.processInfo.isiOSAppOnMac }

    private func fileButton(_ title: String, _ symbol: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await act(action) }
        } label: {
            Label(title, systemImage: symbol)
                .labelStyle(.titleOnly)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NavStyle.text)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(NavStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(busyTask != nil)
        .accessibilityLabel(title)
    }

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
        if !loaded { always = await NavigatorService.permissions() }
        loaded = true
        // "Always allow" on for events or reminders: add them here (this device has the Calendar), and record it.
        for t in tasks where t.status == "needs_ok" && (t.intent == "event" || t.intent == "reminder")
            && always[t.intent] == true && !autoTried.contains(t.id) {
            autoTried.insert(t.id)
            guard let sc = t.plan?.schedule else { continue }
            if let place = try? await NorthstarCalendar.shared.add(sc) {
                await NavigatorService.finish(t.id, added: true, where: place, auto: true)
            }
        }
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
