import SwiftUI

// Search: find anything you've said, by a word or a whole sentence.
// Finds by words and by meaning ("cake shop" finds "bakery").
// Only the matching one-liners are shown, never the whole list.

struct NotesSearchView: View {
    @State private var query = ""
    @State private var results: [Note] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searched = ""          // the query the results belong to
    @State private var opened: Note?
    @State private var deleteFailed = false
    @FocusState private var fieldFocused: Bool

    private let notes = NotesService()

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()

            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                content
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fieldFocused = true }
        // Search a moment after typing stops.
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = nil
            guard q.count >= 2 else {
                results = []; searched = ""; isSearching = false
                return
            }
            isSearching = true
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await run(q)
        }
        .sheet(item: $opened) { note in
            NoteDetailSheet(note: note) {
                Task { await delete(note) }
                opened = nil
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Couldn't delete that note", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    // MARK: - Pieces

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)
            TextField("", text: $query, prompt: Text("A word or a sentence").foregroundStyle(NorthstarChatStyle.label))
                .focused($fieldFocused)
                .foregroundStyle(.white)
                .font(.body)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(NorthstarChatStyle.label)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            message(icon: "exclamationmark.triangle", title: errorMessage, detail: "Check your connection and try again.")
        } else if searched.isEmpty || (isSearching && results.isEmpty) {
            if isSearching { VStack { ProgressView().tint(.white).padding(.top, 48); Spacer() } }
            else {
                message(icon: "text.magnifyingglass",
                        title: "Find anything you've said",
                        detail: "Type a word or a sentence. Northstar finds it by words and by meaning.")
            }
        } else if results.isEmpty && !isSearching {
            message(icon: "magnifyingglass", title: "Nothing found", detail: "Try other words, or say it a different way.")
        } else {
            resultList
        }
    }

    private var resultList: some View {
        List {
            Text(results.count == 1 ? "1 found" : "\(results.count) found")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(results) { note in
                Button { opened = note } label: { NoteRow(note: note, query: searched) }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await delete(note) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .opacity(isSearching ? 0.6 : 1)
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(NorthstarChatStyle.label)
            Text(title).font(.headline).foregroundStyle(.white)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(NorthstarChatStyle.soft)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 48)
    }

    // MARK: - Actions

    private var currentQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func run(_ q: String) async {
        do {
            let found = try await notes.search(q)
            // A newer search may have started; only the latest one updates the screen.
            guard q == currentQuery, !Task.isCancelled else { return }
            results = found
            searched = q
            errorMessage = nil
        } catch {
            guard q == currentQuery, !Task.isCancelled else { return }
            errorMessage = "Search didn't work."
        }
        isSearching = false
    }

    private func delete(_ note: Note) async {
        do {
            try await notes.delete(id: note.id)
            results.removeAll { $0.id == note.id }
        } catch {
            deleteFailed = true
        }
    }
}

// MARK: - One result

private struct NoteRow: View {
    let note: Note
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(note.createdAt, format: .dateTime.month(.abbreviated).day())
                if let subject = note.subject, !subject.isEmpty {
                    Text("·")
                    Text(subject).lineLimit(1)
                }
            }
            .font(.footnote)
            .foregroundStyle(NorthstarChatStyle.label)

            Text(Highlight.bold(note.text, matching: query))
                .font(.body)
                .foregroundStyle(.white)
                .northstarReadingStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows what Northstar answered")
    }
}

// MARK: - Tap a result: what you said, and what Northstar answered

private struct NoteDetailSheet: View {
    let note: Note
    var onDelete: () -> Void

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 6) {
                        Text(note.createdAt, format: .dateTime.month(.wide).day().year())
                        if let subject = note.subject, !subject.isEmpty {
                            Text("·")
                            Text(subject)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)

                    block(label: "NOTED", text: note.text, strong: true)

                    if let context = note.context, !context.isEmpty {
                        block(label: "NORTHSTAR SAID", text: context, strong: false)
                    }

                    Button(role: .destructive, action: onDelete) {
                        Label("Delete this note", systemImage: "trash")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
    }

    private func block(label: String, text: String, strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(NorthstarChatStyle.label)
            Text(text)
                .font(strong ? .title3.weight(.semibold) : .body)
                .foregroundStyle(strong ? .white : NorthstarChatStyle.soft)
                .northstarReadingStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Bold the matched words

enum Highlight {
    /// Bolds words in `text` that start like a search word (3+ letters),
    /// so "bake" bolds "bakery". Meaning-only matches simply show unbolded.
    static func bold(_ text: String, matching query: String) -> AttributedString {
        var out = AttributedString(text)
        let words = query.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        guard !words.isEmpty else { return out }

        // Walk the original text (its indices map into the AttributedString).
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index].isLetter || text[index].isNumber else { index = text.index(after: index); continue }
            var end = index
            while end < text.endIndex, text[end].isLetter || text[end].isNumber { end = text.index(after: end) }
            let word = text[index..<end].lowercased()
            if words.contains(where: { word.hasPrefix($0) || $0.hasPrefix(word) && word.count >= 4 }),
               let lo = AttributedString.Index(index, within: out),
               let hi = AttributedString.Index(end, within: out) {
                out[lo..<hi].inlinePresentationIntent = .stronglyEmphasized
            }
            index = end
        }
        return out
    }

    private static let stopWords: Set<String> = ["the", "and", "for", "with", "that", "this", "you", "your", "are", "was", "what", "how", "from"]
}

#Preview {
    NavigationStack { NotesSearchView() }
}
