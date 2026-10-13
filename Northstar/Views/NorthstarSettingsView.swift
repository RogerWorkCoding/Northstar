import SwiftUI

// Settings (approved design), first version: only switches that really work.
// Read aloud, reduce motion and check-ins come later.

// MARK: - Keys
// One place for every setting key, so the Engine and the Settings screen
// always read and write the same values.

enum SettingsKeys {
    static let memoryOn      = "ns.memory.on"
    static let answerLength  = "ns.talk.answerLength"
    static let showVisuals   = "ns.talk.showVisuals"
    static let preferredName = "ns.talk.preferredName"
    static let easierFont    = "ns.reading.easierFont"
}

nonisolated enum AnswerLength: String, CaseIterable, Identifiable, Sendable {
    case short, detailed
    var id: String { rawValue }
    var label: String { self == .short ? "Short" : "Detailed" }
}

// MARK: - Settings screen

struct NorthstarSettingsView: View {
    @AppStorage(SettingsKeys.memoryOn) private var memoryOn = true
    @AppStorage(SettingsKeys.answerLength) private var answerLength = AnswerLength.short
    @AppStorage(SettingsKeys.showVisuals) private var showVisuals = true
    @AppStorage(SettingsKeys.preferredName) private var preferredName = ""
    @AppStorage(SettingsKeys.easierFont) private var easierFont = false

    @State private var confirmDeleteAll = false
    @State private var exportText = "[]"
    @State private var statusMessage: String?

    private let memoryService = MemoryService()
    private let notesService = NotesService()

    var body: some View {
        Form {
            // 1. Memory and privacy
            Section {
                Toggle("Memory", isOn: $memoryOn)

                if memoryOn {
                    NavigationLink("Review memory") {
                        MemorySearchView()
                    }
                }

                ShareLink(item: exportText, preview: SharePreview("My Northstar memory")) {
                    Label("Export my memory", systemImage: "square.and.arrow.up")
                }

                Button("Delete all memory", role: .destructive) {
                    confirmDeleteAll = true
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Memory and privacy")
            } footer: {
                Text("Northstar only remembers what you say or confirm, plus one-line notes you can find in Search (never feelings or health). You can see, change or delete any of it. When memory is off, nothing is saved or used.")
            }

            // 2. How Northstar talks to you
            Section {
                TextField("What should Northstar call you?", text: $preferredName)
                    .textContentType(.givenName)

                Picker("Answer length", selection: $answerLength) {
                    ForEach(AnswerLength.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Toggle("Show visuals when they help", isOn: $showVisuals)
            } header: {
                Text("How Northstar talks to you")
            }

            // 3. Reading
            Section {
                Toggle("Easier reading", isOn: $easierFont)
            } header: {
                Text("Reading")
            } footer: {
                Text("Adds extra space between letters and lines in Northstar's replies. Text size follows your iPhone's settings.")
            }
        }
        .navigationTitle("Settings")
        .task { await loadExport() }
        .confirmationDialog("Delete all memory?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all memory", role: .destructive) {
                Task { await deleteAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every destination, decision, preference and note Northstar remembers. It can't be undone.")
        }
    }

    private func loadExport() async {
        let id = SupabaseManager.shared.identityId
        guard let items = try? await memoryService.loadMemories(identityId: id) else { return }
        let saved = items.map { ["kind": $0.category ?? "", "text": $0.content] }
        let notes = ((try? await notesService.recent()) ?? []).map {
            ["kind": "note", "text": $0.text, "subject": $0.subject ?? "",
             "date": ISO8601DateFormatter().string(from: $0.createdAt)]
        }
        let rows = saved + notes
        if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted]),
           let text = String(data: data, encoding: .utf8) {
            exportText = text
        }
    }

    private func deleteAll() async {
        let id = SupabaseManager.shared.identityId
        do {
            try await notesService.deleteAll()
            let items = try await memoryService.loadMemories(identityId: id)
            for item in items {
                try await memoryService.deleteMemory(id: item.id)
            }
            statusMessage = "All memory deleted."
        } catch {
            statusMessage = "Couldn't delete everything. Please try again."
        }
        await loadExport()
    }
}

// MARK: - Easier reading

struct NorthstarReadingStyle: ViewModifier {
    @AppStorage(SettingsKeys.easierFont) private var easierFont = false

    func body(content: Content) -> some View {
        if easierFont {
            content
                .tracking(0.6)
                .lineSpacing(8)
        } else {
            content
                .lineSpacing(5)
        }
    }
}

extension View {
    func northstarReadingStyle() -> some View { modifier(NorthstarReadingStyle()) }
}

// MARK: - What the Engine reads

struct EngineSettings: Sendable {
    let memoryOn: Bool
    let answerLength: AnswerLength
    let showVisuals: Bool
    let preferredName: String

    static var current: EngineSettings {
        let d = UserDefaults.standard
        return EngineSettings(
            memoryOn: d.object(forKey: SettingsKeys.memoryOn) as? Bool ?? true,
            answerLength: AnswerLength(rawValue: d.string(forKey: SettingsKeys.answerLength) ?? "") ?? .short,
            showVisuals: d.object(forKey: SettingsKeys.showVisuals) as? Bool ?? true,
            preferredName: d.string(forKey: SettingsKeys.preferredName) ?? ""
        )
    }
}

#Preview {
    NavigationStack { NorthstarSettingsView() }
}
