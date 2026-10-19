import SwiftUI
import PhotosUI
import PDFKit
import LocalAuthentication
import UniformTypeIdentifiers

// 📓 My Journal (Good Listener module): the person's own entries, photos and PDFs, on this phone only.
// "Talk this through" opens a new chat with one entry; "Notes for my counselor" makes notes to share.

struct JournalView: View {
    /// Opens a new chat with this text (and photo) as their first message.
    var onTalk: (String, Data?) -> Void

    @State private var store = JournalStore.shared
    @AppStorage("ns.journalLock") private var lockOn = false
    @State private var unlocked = false
    @State private var editing: JournalItem?
    @State private var showCounselor = false
    @State private var lockProblem: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            if lockOn && !unlocked {
                lockedView
            } else {
                list
            }
        }
        .navigationTitle("My Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !lockOn || unlocked {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = JournalItem(title: "", text: "")
                    } label: {
                        Label("New entry", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(item: $editing) { item in
            NavigationStack { JournalEditor(item: item, isNew: store.entry(item.id) == nil) }
        }
        .sheet(isPresented: $showCounselor) {
            NavigationStack { CounselorNotesView() }
        }
        .task { if lockOn && !unlocked { await unlock() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlocked = false }   // locks again when they leave the app
        }
    }

    private var list: some View {
        List {
            if let problem = store.problem {
                Text(problem).foregroundStyle(NorthstarChatStyle.warning)
            }
            Section {
                Button {
                    editing = JournalItem(title: "", text: "")
                } label: {
                    Label("Write a new entry", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                if !store.entries.isEmpty {
                    Button {
                        showCounselor = true
                    } label: {
                        Label("Notes for my counselor", systemImage: "doc.text")
                            .font(.headline)
                            .frame(minHeight: 44)
                    }
                }
            } footer: {
                Text("Your journal stays on this phone. Nothing is shared unless you choose to.")
            }

            if store.entries.isEmpty {
                Section {
                    Text("No entries yet. Write one here, or say yes when Northstar offers to save something you shared.")
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
            } else {
                Section("Entries") {
                    ForEach(store.entries) { item in
                        NavigationLink {
                            JournalEntryView(id: item.id, onTalk: onTalk)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline)
                                HStack(spacing: 6) {
                                    Text(item.created, format: .dateTime.month(.wide).day().year())
                                    if !item.attachments.isEmpty {
                                        Image(systemName: "paperclip").accessibilityLabel("Has files")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(NorthstarChatStyle.label)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: Binding(get: { lockOn }, set: { on in
                    if on { Task { await turnOnLock() } } else { lockOn = false }
                })) {
                    Label("Lock with Face ID", systemImage: "faceid")
                }
                if let lockProblem {
                    Text(lockProblem).font(.footnote).foregroundStyle(NorthstarChatStyle.warning)
                }
            } footer: {
                Text("Asks for Face ID or your passcode each time you open My Journal.")
            }
        }
        .scrollContentBackground(.hidden)
        .foregroundStyle(NorthstarChatStyle.text)
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .light))
                .accessibilityHidden(true)
            Text("My Journal is locked").font(.title2)
            Button {
                Task { await unlock() }
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .font(.headline)
                    .foregroundStyle(NorthstarChatStyle.onPrimary)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 50)
                    .background(Capsule().fill(NorthstarChatStyle.primaryFill))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(NorthstarChatStyle.text)
    }

    private func unlock() async {
        unlocked = await Self.authenticate("Open your journal")
    }

    private func turnOnLock() async {
        if await Self.authenticate("Lock your journal") {
            lockOn = true
            unlocked = true
            lockProblem = nil
        } else {
            lockProblem = "Face ID or a passcode needs to be set up on this iPhone first."
        }
    }

    /// Face ID, Touch ID or the phone's passcode.
    static func authenticate(_ reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

// MARK: - One entry

struct JournalEntryView: View {
    let id: UUID
    var onTalk: (String, Data?) -> Void

    @State private var store = JournalStore.shared
    @State private var editing: JournalItem?
    @State private var confirmDelete = false
    @State private var openPDF: JournalAttachment?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            if let item = store.entry(id) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(item.title)
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(item.created, format: .dateTime.weekday(.wide).month(.wide).day().year())
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.label)
                        Text(item.text)
                            .font(.system(size: 19))
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(item.attachments) { a in attachmentRow(a) }

                        Button {
                            onTalk(Self.talkMessage(item), Self.firstImage(item))
                        } label: {
                            Label("Talk this through", systemImage: "bubble.left.and.bubble.right")
                                .font(.headline)
                                .foregroundStyle(NorthstarChatStyle.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens a new chat with this entry")
                        Text("This entry is sent to Northstar only for that chat.")
                            .font(.caption)
                            .foregroundStyle(NorthstarChatStyle.label)
                    }
                    .foregroundStyle(NorthstarChatStyle.text)
                    .padding(20)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Edit", systemImage: "pencil") { editing = item }
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        store.delete(item)
                        dismiss()
                    }
                } message: {
                    Text("It can't be brought back.")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            NavigationStack { JournalEditor(item: item, isNew: false) }
        }
        .sheet(item: $openPDF) { a in
            NavigationStack {
                PDFKitView(url: store.url(for: a))
                    .navigationTitle(a.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { openPDF = nil } } }
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(_ a: JournalAttachment) -> some View {
        switch a.kind {
        case .image:
            if let data = store.data(for: a), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(a.name)
            }
        case .pdf:
            Button { openPDF = a } label: {
                Label(a.name, systemImage: "doc.richtext")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(NorthstarChatStyle.card))
            }
            .buttonStyle(.plain)
        }
    }

    /// Their entry, as the first message of a new chat (PDF text included, shortened).
    static func talkMessage(_ item: JournalItem) -> String {
        var parts = ["I'd like to talk through this journal entry of mine.", "Title: \(item.title)", item.text]
        for a in item.attachments where a.kind == .pdf {
            if let doc = PDFDocument(url: JournalStore.shared.url(for: a)), let text = doc.string?
                .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                parts.append("From my document \u{201C}\(a.name)\u{201D}:\n" + String(text.prefix(6000)))
            }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    static func firstImage(_ item: JournalItem) -> Data? {
        guard let a = item.attachments.first(where: { $0.kind == .image }) else { return nil }
        return JournalStore.shared.data(for: a)
    }
}

// MARK: - Write or edit

struct JournalEditor: View {
    @State var item: JournalItem
    let isNew: Bool

    @State private var store = JournalStore.shared
    @State private var photo: PhotosPickerItem?
    @State private var pickPDF = false
    /// Files added in this editor (removed again if they cancel).
    @State private var added: [JournalAttachment] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Title") {
                TextField("A short title", text: $item.title)
            }
            Section("Entry") {
                TextEditor(text: $item.text)
                    .frame(minHeight: 220)
                    .font(.system(size: 18))
            }
            Section {
                ForEach(item.attachments) { a in
                    Label(a.name, systemImage: a.kind == .pdf ? "doc.richtext" : "photo")
                }
                .onDelete { item.attachments.remove(atOffsets: $0) }
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Add a photo", systemImage: "photo.badge.plus").frame(minHeight: 44)
                }
                Button { pickPDF = true } label: {
                    Label("Add a PDF", systemImage: "doc.badge.plus").frame(minHeight: 44)
                }
            } header: {
                Text("Photos and documents")
            } footer: {
                Text("About you: a letter, a note, a page you wrote. Kept on this phone.")
            }
        }
        .navigationTitle(isNew ? "New entry" : "Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    store.discard(added)
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if isNew {
                        store.add(title: item.title, text: item.text, attachments: item.attachments)
                    } else {
                        store.update(item)
                    }
                    dismiss()
                }
                .disabled(item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.attachments.isEmpty)
            }
        }
        .onChange(of: photo) { _, picked in
            guard let picked else { return }
            Task {
                if let data = try? await picked.loadTransferable(type: Data.self),
                   let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85),
                   let a = store.saveAttachment(jpeg, kind: .image, name: "Photo") {
                    item.attachments.append(a)
                    added.append(a)
                }
                photo = nil
            }
        }
        .fileImporter(isPresented: $pickPDF, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url),
               let a = store.saveAttachment(data, kind: .pdf, name: url.lastPathComponent) {
                item.attachments.append(a)
                added.append(a)
            }
        }
        .interactiveDismissDisabled()
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
