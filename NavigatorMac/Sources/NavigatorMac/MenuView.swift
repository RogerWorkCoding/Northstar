import SwiftUI
import AppKit

// The window under the menu bar star: status, link, folders, what it found, Pause / Stop.
struct MenuView: View {
    @Bindable var model: NavigatorModel
    private let gold = Color(red: 0.91, green: 0.75, blue: 0.42)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            if !model.isLinked {
                linkSection
            } else {
                foldersSection
                Divider()
                workSection
                Divider()
                footer
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Northstar Navigator").font(.headline)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Looks only")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(gold.opacity(0.22)))
                .help("Step 1: Navigator only searches. It never moves, changes, sends or deletes anything.")
        }
    }

    private var statusColor: Color {
        if !model.isLinked { return .gray }
        if model.isPaused { return .orange }
        if model.problem != nil { return .red }
        return model.isWorking ? gold : .green
    }

    private var statusText: String {
        if !model.isLinked { return "Not linked to your iPhone yet" }
        if model.isPaused { return "Paused" }
        if model.folders.isEmpty { return "Choose folders to start" }
        if let p = model.problem { return p }
        return model.isWorking ? "Working" : "Ready · linked to your iPhone"
    }

    // MARK: Linking

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Link to your iPhone").font(.subheadline.weight(.semibold))
            Text("In Northstar on your iPhone, tap the compass under the text field, then Link a Mac. Type the code here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("ABCD-EFGH", text: $model.linkCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { Task { await model.link() } }
                Button("Link") { Task { await model.link() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.linkCode.trimmingCharacters(in: .whitespaces).count < 8)
            }
            if let m = model.linkMessage {
                Text(m).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Folders

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Folders it may look in").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Choose\u{2026}") { model.chooseFolders() }
            }
            if model.folders.isEmpty {
                Text("None yet. Navigator searches only the folders you choose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.folders, id: \.self) { folder in
                HStack(spacing: 8) {
                    Image(systemName: "folder").foregroundStyle(gold)
                    Text(folder.lastPathComponent).lineLimit(1)
                    Spacer()
                    Button {
                        model.remove(folder)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(folder.lastPathComponent)")
                }
                .font(.callout)
            }
        }
    }

    // MARK: Work

    private var workSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let now = model.now {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(now).font(.callout)
                }
            }
            HStack(spacing: 8) {
                Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }
                Button(role: .destructive) { model.stopNow() } label: { Text("Stop now") }
                    .disabled(!model.isWorking)
            }
            Text("Recent").font(.subheadline.weight(.semibold)).padding(.top, 4)
            if model.recent.isEmpty {
                Text("Ask on your iPhone, for example: \u{201C}Find my car insurance PDF.\u{201D}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.recent) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\u{201C}\(task.request)\u{201D}").font(.callout.weight(.medium)).lineLimit(2)
                            Text(task.failed ?? "Found \(task.files.count)")
                                .font(.caption)
                                .foregroundStyle(task.failed == nil ? Color.secondary : Color.red)
                            ForEach(task.files.prefix(5)) { file in
                                Button { model.reveal(file) } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc")
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(file.url.lastPathComponent).lineLimit(1)
                                            Text(file.folderLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                                .buttonStyle(.borderless)
                                .help("Show in Finder")
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Open record") { model.openRecord() }
                .help("Every step Navigator took on this Mac, written by its own code.")
            Button("Unlink") { model.unlink() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
