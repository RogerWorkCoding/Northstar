import SwiftUI
import AVKit

// 🎬 Videos (star menu): everything the person saved — YouTube lessons and videos they made —
// in their own folders, folders inside folders. Tap a folder to open it; tap a video to watch.
// ⋯ on any row: Rename, Move, Delete. New folder in the top right.
// Drag and drop: hold a video or folder, then drag it onto a folder to move it there
// (or onto "Move up" at the top to take it out of this folder).

struct VideoLibraryView: View {
    /// nil = the top level.
    var folder: VideoFolder? = nil

    @State private var folders: [VideoFolder] = []
    @State private var videos: [SavedVideo] = []
    @State private var loaded = false
    @State private var failed = false

    @State private var naming: Naming?
    @State private var nameText = ""
    @State private var moving: Moving?
    @State private var deletingFolder: VideoFolder?
    @State private var playingYouTube: NorthstarInsight.LessonVideo?
    @State private var playingMade: PlayItem?
    /// The folder (or "move up" row) a dragged item is hovering over, for the highlight.
    @State private var dropTarget: String?

    private let library = VideoLibraryService()

    private enum Naming: Identifiable {
        case newFolder, renameFolder(VideoFolder), renameVideo(SavedVideo)
        var id: String {
            switch self {
            case .newFolder: return "new"
            case .renameFolder(let f): return "f\(f.id)"
            case .renameVideo(let v): return "v\(v.id)"
            }
        }
    }
    private enum Moving: Identifiable {
        case folder(VideoFolder), video(SavedVideo)
        var id: String {
            switch self { case .folder(let f): return "f\(f.id)"; case .video(let v): return "v\(v.id)" }
        }
    }
    private struct PlayItem: Identifiable { let id = UUID(); let url: URL; let title: String }

    private var here: UUID? { folder?.id }
    private var subfolders: [VideoFolder] { folders.filter { $0.parentId == here } }
    private var videosHere: [SavedVideo] { videos.filter { $0.folderId == here } }

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            if !loaded {
                ProgressView().tint(.white)
            } else if failed {
                message(icon: "exclamationmark.triangle", title: "Couldn't load your videos",
                        detail: "Check your connection and try again.")
            } else if subfolders.isEmpty && videosHere.isEmpty {
                message(icon: "film.stack", title: folder == nil ? "No saved videos yet" : "This folder is empty",
                        detail: folder == nil
                            ? "When Northstar shows a video, tap Save to keep it here. Make folders to organize them."
                            : "Save videos here from a chat, or move them in with ⋯ → Move.")
            } else {
                list
            }
        }
        .navigationTitle(folder.map { f in folders.first { $0.id == f.id }?.name ?? f.name } ?? "Videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { nameText = ""; naming = .newFolder } label: { Image(systemName: "folder.badge.plus") }
                    .accessibilityLabel("New folder")
            }
        }
        // Reload when coming back from a folder, so moves made inside it show here too.
        .onAppear { Task { await load() } }
        .alert(namingTitle, isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $nameText)
            Button("Save") { let what = naming; let text = nameText; Task { await applyName(what, text) } }
            Button("Cancel", role: .cancel) { naming = nil }
        }
        .confirmationDialog("Delete this folder?", isPresented: Binding(get: { deletingFolder != nil }, set: { if !$0 { deletingFolder = nil } }), titleVisibility: .visible) {
            Button("Delete folder and everything in it", role: .destructive) {
                if let f = deletingFolder { Task { try? await library.deleteFolder(f.id); await load() } }
            }
        } message: {
            Text("Folders and videos inside it are removed from your Videos. Videos you made stay in your account until you delete your account.")
        }
        .sheet(item: $moving) { item in
            MovePicker(folders: folders, excluding: movingExclusions(item)) { target in
                Task {
                    switch item {
                    case .folder(let f): try? await library.moveFolder(f.id, into: target)
                    case .video(let v): try? await library.moveVideo(v.id, into: target)
                    }
                    moving = nil
                    await load()
                }
            }
        }
        .sheet(item: $playingYouTube) { VideoSheet(video: $0) }
        .sheet(item: $playingMade) { item in
            NavigationStack {
                VideoPlayer(player: AVPlayer(url: item.url))
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { playingMade = nil } } }
            }
        }
    }

    private var list: some View {
        List {
            if let folder {
                // Drop here to take something out of this folder (up one level).
                let parentName = folders.first { $0.id == folder.parentId }?.name ?? "Videos"
                Label("Drag here to move up to \(parentName)", systemImage: "arrow.up.doc")
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .listRowBackground(dropTarget == "up" ? NorthstarChatStyle.linkBlue.opacity(0.35) : Color.clear)
                    .dropDestination(for: String.self) { items, _ in
                        drop(items, into: folder.parentId)
                    } isTargeted: { over in
                        if over { dropTarget = "up" } else if dropTarget == "up" { dropTarget = nil }
                    }
                    .accessibilityLabel("Move up to \(parentName)")
                    .accessibilityHint("Drop a video or folder here to move it out of this folder")
            }
            if !subfolders.isEmpty {
                Section {
                    ForEach(subfolders) { sub in
                        NavigationLink {
                            VideoLibraryView(folder: sub)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: dropTarget == sub.id.uuidString ? "folder.fill.badge.plus" : "folder.fill")
                                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                                Text(sub.name).foregroundStyle(NorthstarChatStyle.text)
                                Spacer()
                                Text("\(count(in: sub))").font(.footnote).foregroundStyle(NorthstarChatStyle.label)
                            }
                        }
                        .listRowBackground(dropTarget == sub.id.uuidString
                                           ? NorthstarChatStyle.linkBlue.opacity(0.35) : Color.white.opacity(0.06))
                        .draggable(Self.dragKey(folder: sub.id)) { dragPreview(icon: "folder.fill", title: sub.name) }
                        .dropDestination(for: String.self) { items, _ in
                            drop(items, into: sub.id)
                        } isTargeted: { over in
                            if over { dropTarget = sub.id.uuidString } else if dropTarget == sub.id.uuidString { dropTarget = nil }
                        }
                        .accessibilityHint("Hold and drag videos or folders here to move them in")
                        .contextMenu { folderMenu(sub) }
                        .swipeActions { Button(role: .destructive) { deletingFolder = sub } label: { Label("Delete", systemImage: "trash") } }
                    }
                } header: { header("Folders") }
            }
            if !videosHere.isEmpty {
                Section {
                    ForEach(videosHere) { video in
                        Button { Task { await play(video) } } label: { videoRow(video) }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.white.opacity(0.06))
                            .draggable(Self.dragKey(video: video.id)) {
                                dragPreview(icon: video.isYouTube ? "play.rectangle.fill" : "sparkles.tv", title: video.title)
                            }
                            .contextMenu { videoMenu(video) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { try? await library.deleteVideo(video.id); await load() }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                } header: { header("Videos") }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func videoRow(_ video: SavedVideo) -> some View {
        HStack(spacing: 12) {
            Group {
                if let id = video.youtubeId {
                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg")) { $0.resizable().aspectRatio(16 / 9, contentMode: .fill) }
                        placeholder: { Color.white.opacity(0.08) }
                } else {
                    ZStack { Color.white.opacity(0.08); Image(systemName: "sparkles.tv").foregroundStyle(.white) }
                }
            }
            .frame(width: 80, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(video.title).font(.subheadline.weight(.semibold)).foregroundStyle(NorthstarChatStyle.text).lineLimit(2)
                Text(video.isYouTube ? "YouTube" : "Made with Northstar").font(.caption).foregroundStyle(NorthstarChatStyle.label)
            }
            Spacer(minLength: 4)
            Menu { videoMenu(video) } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(NorthstarChatStyle.label).frame(width: 36, height: 36)
            }
            .accessibilityLabel("More for \(video.title)")
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private func folderMenu(_ f: VideoFolder) -> some View {
        Button { nameText = f.name; naming = .renameFolder(f) } label: { Label("Rename", systemImage: "pencil") }
        Button { moving = .folder(f) } label: { Label("Move…", systemImage: "folder") }
        Button(role: .destructive) { deletingFolder = f } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder private func videoMenu(_ v: SavedVideo) -> some View {
        Button { nameText = v.title; naming = .renameVideo(v) } label: { Label("Rename", systemImage: "pencil") }
        Button { moving = .video(v) } label: { Label("Move…", systemImage: "folder") }
        Button(role: .destructive) { Task { try? await library.deleteVideo(v.id); await load() } } label: { Label("Delete", systemImage: "trash") }
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(NorthstarChatStyle.label)
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(NorthstarChatStyle.label)
            Text(title).font(.headline).foregroundStyle(.white)
            Text(detail).font(.subheadline).foregroundStyle(NorthstarChatStyle.soft).multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var namingTitle: String {
        switch naming {
        case .newFolder: return "New folder"
        case .renameFolder: return "Rename folder"
        case .renameVideo: return "Rename video"
        case nil: return ""
        }
    }

    /// Videos and folders directly inside a folder (shown next to its name).
    private func count(in f: VideoFolder) -> Int {
        videos.filter { $0.folderId == f.id }.count + folders.filter { $0.parentId == f.id }.count
    }

    /// A folder can't move into itself or anything inside it.
    private func movingExclusions(_ item: Moving) -> Set<UUID> {
        guard case .folder(let f) = item else { return [] }
        var out: Set<UUID> = [f.id]
        var changed = true
        while changed {
            changed = false
            for x in folders where x.parentId.map(out.contains) == true && !out.contains(x.id) {
                out.insert(x.id); changed = true
            }
        }
        return out
    }

    // MARK: Drag and drop

    private static func dragKey(video id: UUID) -> String { "ns-video:\(id.uuidString)" }
    private static func dragKey(folder id: UUID) -> String { "ns-folder:\(id.uuidString)" }

    private func dragPreview(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(NorthstarChatStyle.userBubble))
    }

    /// Moves what was dropped into `target` (nil = top level). Ignores anything that isn't
    /// one of this person's videos or folders, and never puts a folder inside itself.
    private func drop(_ items: [String], into target: UUID?) -> Bool {
        dropTarget = nil
        var moves: [Moving] = []
        for item in items {
            if item.hasPrefix("ns-video:"), let id = UUID(uuidString: String(item.dropFirst(9))),
               let v = videos.first(where: { $0.id == id }), v.folderId != target {
                moves.append(.video(v))
            } else if item.hasPrefix("ns-folder:"), let id = UUID(uuidString: String(item.dropFirst(10))),
                      let f = folders.first(where: { $0.id == id }), f.parentId != target,
                      !(target.map { movingExclusions(.folder(f)).contains($0) } ?? false) {
                moves.append(.folder(f))
            }
        }
        guard !moves.isEmpty else { return false }
        Task {
            for move in moves {
                switch move {
                case .video(let v): try? await library.moveVideo(v.id, into: target)
                case .folder(let f): try? await library.moveFolder(f.id, into: target)
                }
            }
            await load()
        }
        return true
    }

    private func load() async {
        do {
            async let f = library.folders()
            async let v = library.videos()
            (folders, videos) = try await (f, v)
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }

    // `what` is captured when Save is tapped: the alert clears `naming` as it closes.
    private func applyName(_ what: Naming?, _ text: String) async {
        switch what {
        case .newFolder: _ = try? await library.createFolder(name: text, parent: here)
        case .renameFolder(let f): try? await library.renameFolder(f.id, to: text)
        case .renameVideo(let v): try? await library.renameVideo(v.id, to: text)
        case nil: break
        }
        naming = nil
        await load()
    }

    private func play(_ video: SavedVideo) async {
        if let id = video.youtubeId {
            playingYouTube = .init(id: id, title: video.title, url: "https://www.youtube.com/watch?v=\(id)")
        } else if let url = try? await library.playURL(for: video) {
            playingMade = PlayItem(url: url, title: video.title)
        }
    }
}

/// Pick where to move something: the top level or any folder (not into itself).
private struct MovePicker: View {
    let folders: [VideoFolder]
    let excluding: Set<UUID>
    let onPick: (UUID?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button { onPick(nil) } label: { Label("Videos (top level)", systemImage: "film.stack") }
                ForEach(folders.filter { !excluding.contains($0.id) }.sorted {
                    VideoLibraryService.path(of: $0, in: folders) < VideoLibraryService.path(of: $1, in: folders)
                }) { f in
                    Button { onPick(f.id) } label: {
                        Label(VideoLibraryService.path(of: f, in: folders), systemImage: "folder")
                    }
                }
            }
            .navigationTitle("Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
