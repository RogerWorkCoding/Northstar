import SwiftUI

// 🎬 "Save this video?" — shown under videos in chat (YouTube lessons and videos made with Veo).
// Northstar suggests a folder; the person picks any folder (or makes a new one), or says Not now.

struct SaveVideoCard: View {
    let items: [VideoToSave]
    var suggestedFolder: String?

    @State private var folders: [VideoFolder] = []
    @State private var chosen: UUID?
    @State private var newFolderName = ""
    @State private var askingName = false
    @State private var state: SaveState = .asking

    private enum SaveState { case asking, saving, saved(String?), dismissed, failed }
    private let library = VideoLibraryService()

    var body: some View {
        switch state {
        case .dismissed:
            EmptyView()
        case .saved(let folderName):
            Label(folderName.map { "Saved to Videos › \($0)" } ?? "Saved to Videos", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.savedGreen)
        default:
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "film.stack")
                Text(items.count == 1 ? "SAVE THIS VIDEO?" : "SAVE THESE \(items.count) VIDEOS?").tracking(1.5)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NorthstarChatStyle.label)

            Menu {
                if let suggestedFolder, !folders.contains(where: { $0.name.caseInsensitiveCompare(suggestedFolder) == .orderedSame && $0.parentId == nil }) {
                    Button("New: \(suggestedFolder)") { chosen = nil; newFolderName = suggestedFolder }
                }
                ForEach(folders) { folder in
                    Button(VideoLibraryService.path(of: folder, in: folders)) { chosen = folder.id; newFolderName = "" }
                }
                Divider()
                Button("New folder…") { askingName = true }
                Button("No folder") { chosen = nil; newFolderName = "" }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(folderLabel).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.text)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .accessibilityLabel("Folder: \(folderLabel)")

            HStack(spacing: 10) {
                Button {
                    Task { await save() }
                } label: {
                    Text(stateIsSaving ? "Saving…" : "Save")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
                }
                .disabled(stateIsSaving)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { state = .dismissed }
                } label: {
                    Text("Not now")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                }
            }
            .buttonStyle(.plain)

            if case .failed = state {
                Text("Couldn't save. Please try again.").font(.footnote).foregroundStyle(NorthstarChatStyle.label)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .task { await load() }
        .alert("New folder", isPresented: $askingName) {
            TextField("Folder name", text: $newFolderName)
            Button("OK") { chosen = nil }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
    }

    private var stateIsSaving: Bool { if case .saving = state { return true } else { return false } }

    private var folderLabel: String {
        if let chosen, let folder = folders.first(where: { $0.id == chosen }) {
            return VideoLibraryService.path(of: folder, in: folders)
        }
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "No folder" : "New: \(name)"
    }

    private func load() async {
        folders = (try? await library.folders()) ?? []
        // Start with Northstar's suggestion: an existing folder with that name, or a new one.
        if chosen == nil, newFolderName.isEmpty, let suggestedFolder {
            if let match = folders.first(where: { $0.parentId == nil && $0.name.caseInsensitiveCompare(suggestedFolder) == .orderedSame }) {
                chosen = match.id
            } else {
                newFolderName = suggestedFolder
            }
        }
    }

    private func save() async {
        state = .saving
        do {
            var folderId = chosen
            var folderName = folderLabel
            let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if folderId == nil, !name.isEmpty {
                let folder = try await library.folderNamed(name)
                folderId = folder.id
                folderName = folder.name
            }
            for item in items { try await library.save(item, in: folderId) }
            withAnimation(.easeOut(duration: 0.2)) { state = .saved(folderId == nil ? nil : folderName) }
        } catch {
            state = .failed
        }
    }
}
