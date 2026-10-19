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

// MARK: - The screen

struct NavigatorView: View {
    @State private var macs: [NavigatorMacInfo] = []
    @State private var tasks: [NavigatorTask] = []
    @State private var code: String?
    @State private var draft = ""
    @State private var sending = false
    @State private var problem: String?
    @State private var loaded = false

    private let examples = ["Find my car insurance PDF", "Find images from last week", "Where's my lease?"]

    var body: some View {
        Form {
            Section {
                Label("Step 1 only looks. It never moves, changes, sends or deletes anything.", systemImage: "eye")
                    .font(.subheadline)
            }

            Section {
                if macs.isEmpty && loaded {
                    Text("No Mac linked yet.").foregroundStyle(.secondary)
                }
                ForEach(macs) { mac in
                    HStack {
                        Label(mac.name, systemImage: "laptopcomputer")
                        Spacer()
                        Button("Unlink", role: .destructive) {
                            Task { await NavigatorService.unlink(mac.id); await refresh() }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if let code {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(code)
                            .font(.system(size: 34, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityLabel("Code: \(code.map { String($0) }.joined(separator: " "))")
                        Text("Type this in Navigator on your Mac (the star in the menu bar). It works for 10 minutes, once.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    Task {
                        code = await NavigatorService.pairCode()?.code
                        if code == nil { problem = "Couldn't make a code. Please try again." }
                    }
                } label: {
                    Label(code == nil ? "Link a Mac" : "Make a new code", systemImage: "link")
                }
            } header: {
                Text("Your Mac")
            }

            Section {
                TextField("What should Navigator find?", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit { Task { await send() } }
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        if sending { ProgressView() }
                        Text("Ask my Mac").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending || macs.isEmpty)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(examples, id: \.self) { e in
                            Button(e) { draft = e }
                                .buttonStyle(.bordered)
                                .font(.footnote)
                        }
                    }
                }
                if let problem {
                    Text(problem).foregroundStyle(.red).font(.footnote)
                }
            } header: {
                Text("Ask")
            } footer: {
                Text(macs.isEmpty ? "Link a Mac first." : "Your Mac searches only the folders you chose there.")
            }

            ForEach(tasks) { task in
                Section {
                    taskBody(task)
                } header: {
                    Text("\u{201C}\(task.request)\u{201D}")
                }
            }
        }
        .navigationTitle("Navigator")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .task {
            // Keep the list fresh while something is being worked on.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if tasks.contains(where: \.isActive) || code != nil { await refresh() }
            }
        }
        .refreshable { await refresh() }
    }

    @ViewBuilder
    private func taskBody(_ task: NavigatorTask) -> some View {
        switch task.status {
        case "queued", "running":
            HStack {
                ProgressView()
                Text(task.status == "queued" ? "Waiting for your Mac\u{2026}" : "Your Mac is looking\u{2026}")
                Spacer()
                Button("Stop", role: .destructive) { Task { await NavigatorService.stop(task.id); await refresh() } }
                    .buttonStyle(.bordered)
            }
        case "failed":
            Text(task.error ?? "Something went wrong.").foregroundStyle(.red)
        case "stopped":
            Text("Stopped.").foregroundStyle(.secondary)
        default:
            let files = task.result?.files ?? []
            if files.isEmpty {
                Text("Nothing found in \((task.result?.searched ?? []).joined(separator: ", ")).")
                    .foregroundStyle(.secondary)
            }
            ForEach(files, id: \.self) { f in
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(.body.weight(.medium)).lineLimit(2)
                    Text([f.folder, shortDate(f.modified)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            Text("To open one, click it in Navigator on your Mac (the star in the menu bar).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if let events = task.events, !events.isEmpty {
            DisclosureGroup("What Navigator did") {
                ForEach(Array(events.enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(e.time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(e.words).font(.footnote)
                    }
                }
            }
            .font(.footnote)
        }
    }

    private func shortDate(_ iso: String?) -> String? {
        guard let iso, let d = ISO8601DateFormatter().date(from: iso) else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).day().year())
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
        if await NavigatorService.ask(text) != nil {
            draft = ""
            await refresh()
        } else {
            problem = "Couldn't send that to your Mac. Please try again."
        }
        sending = false
    }
}
