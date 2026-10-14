import SwiftUI

// Search: find anything you've said, by a word or a whole sentence.
// Finds by words and by meaning ("cake shop" finds "bakery").
// Only the matching one-liners are shown, never the whole list.

struct NotesSearchView: View {
    /// Opens a saved chat (from a note's "Open the chat").
    var onOpenChat: (UUID) -> Void = { _ in }
    @State private var query = ""
    @State private var results: [Note] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searched = ""          // the query the results belong to
    @State private var opened: Note?
    @State private var deleteFailed = false
    @State private var recent: [Note] = []      // newest notes, shown as pills when not searching
    @State private var subjects: [Subject] = []  // kept projects, shown above Recent
    @State private var openedSubject: Subject?
    @State private var subjectFailed = false
    @State private var hintIndex = 0            // which rotating hint is showing
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The search field's hint rotates slowly (still with Reduce Motion, stops when typing).
    private static let hints = [
        "Find anything you've said",
        "Type a word or a sentence",
        "Finds it by words and meaning",
    ]

    private let notes = NotesService()
    private let subjectsService = SubjectsService()

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
        .task { await loadRecent(); await loadSubjects() }
        .sheet(item: $openedSubject) { subject in
            SubjectDetailSheet(subject: subject,
                onDone: { Task { do { try await subjectsService.markDone(id: subject.id) } catch { subjectFailed = true }; await loadSubjects() }; openedSubject = nil },
                onDelete: { Task { do { try await subjectsService.delete(id: subject.id) } catch { subjectFailed = true }; await loadSubjects() }; openedSubject = nil })
            .presentationDetents([.medium, .large])
        }
        // Rotate the hint every 4 seconds while the field is empty.
        .task(id: query.isEmpty) {
            guard query.isEmpty, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled, query.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    hintIndex = (hintIndex + 1) % Self.hints.count
                }
            }
        }
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
            NoteDetailSheet(note: note, onDelete: {
                Task { await delete(note); await loadRecent() }
                opened = nil
            }, onOpenChat: { id in
                opened = nil
                onOpenChat(id)
            })
            .presentationDetents([.medium, .large])
        }
        .alert("Couldn't change that subject", isPresented: $subjectFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
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
            TextField("", text: $query)
                .focused($fieldFocused)
                .accessibilityLabel("Search")
                .accessibilityHint(Self.hints.joined(separator: ". "))
                .background(alignment: .leading) {
                    // The rotating hint (a soft fade, one line at a time).
                    if query.isEmpty {
                        Text(Self.hints[reduceMotion ? 0 : hintIndex])
                            .foregroundStyle(NorthstarChatStyle.label)
                            .lineLimit(1)
                            .id(hintIndex)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
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
        .frostedCapsule()
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            message(icon: "exclamationmark.triangle", title: errorMessage, detail: "Check your connection and try again.")
        } else if searched.isEmpty || (isSearching && results.isEmpty) {
            if isSearching { VStack { ProgressView().tint(.white).padding(.top, 48); Spacer() } }
            else { recentPills }
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

    /// The newest notes as pills. Tap one to open it.
    private var recentPills: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !subjects.isEmpty {
                Text("SUBJECTS")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(NorthstarChatStyle.label)
                VStack(spacing: 10) {
                    ForEach(subjects) { subject in
                        Button { openedSubject = subject } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "scope").foregroundStyle(NorthstarChatStyle.label)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(NorthstarChatStyle.text)
                                        .lineLimit(1)
                                    if let next = subject.nextStep, !next.isEmpty {
                                        Text("Next: \(next)")
                                            .font(.footnote)
                                            .foregroundStyle(NorthstarChatStyle.soft)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(NorthstarChatStyle.label)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .frostedCapsule()
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this subject")
                    }
                }
                .padding(.bottom, 8)
            }
            if !recent.isEmpty {
                Text("RECENT")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(NorthstarChatStyle.label)
                VStack(spacing: 10) {
                    ForEach(recent) { note in
                        Button { opened = note } label: {
                            HStack(spacing: 10) {
                                Text(Self.pillLabel(note))
                                    .font(.body)
                                    .foregroundStyle(NorthstarChatStyle.text)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(NorthstarChatStyle.label)
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .frostedCapsule()
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this note")
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Pill text: the subject if there is one, otherwise the note (cut to one line by width).
    private static func pillLabel(_ note: Note) -> String {
        note.subject?.isEmpty == false ? note.subject! : note.text
    }

    private func loadSubjects() async {
        subjects = (try? await subjectsService.active()) ?? []
    }

    private func loadRecent() async {
        guard let newest = try? await notes.recent(limit: 12) else { return }
        // One pill per subject, newest first, at most 4.
        var seen = Set<String>()
        recent = Array(newest.filter { seen.insert(Self.pillLabel($0).lowercased()).inserted }.prefix(4))
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
    var onOpenChat: (UUID) -> Void = { _ in }

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

                    if let chatId = note.chatId {
                        Button { onOpenChat(chatId) } label: {
                            Label("Open the chat", systemImage: "bubble.left.and.bubble.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
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

// MARK: - Frosted glass (same look as the chat field)

extension View {
    /// Frosted capsule: blur with a soft white tint, a light edge and a faint blue glow.
    func frostedCapsule() -> some View {
        self
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    // Tinted toward navy so the glass belongs to the screen (not grey).
                    Capsule().fill(Color(red: 0.42, green: 0.52, blue: 0.95).opacity(0.14))
                }
                .environment(\.colorScheme, .dark)
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: Color(red: 0.45, green: 0.55, blue: 1.0).opacity(0.15), radius: 12)
    }
}

// MARK: - A subject: goal, decisions and next step

private struct SubjectDetailSheet: View {
    let subject: Subject
    var onDone: () -> Void
    var onDelete: () -> Void

    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                        Text(subject.title)
                    }
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                    if let goal = subject.goal, !goal.isEmpty { block("GOAL", goal) }
                    if !subject.decisions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            label("DECISIONS")
                            ForEach(subject.decisions, id: \.self) { d in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•").foregroundStyle(NorthstarChatStyle.label)
                                    Text(d.text).foregroundStyle(NorthstarChatStyle.text)
                                    Spacer(minLength: 4)
                                    Text(Self.day(d.at)).font(.footnote).foregroundStyle(NorthstarChatStyle.label)
                                }
                                .font(.body)
                                .northstarReadingStyle()
                            }
                        }
                    }
                    if let next = subject.nextStep, !next.isEmpty { block("NEXT STEP", next) }

                    HStack(spacing: 10) {
                        Button(action: onDone) {
                            Label("Mark done", systemImage: "checkmark")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .confirmationDialog("Delete \(subject.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the card. Your notes stay in Search.")
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(NorthstarChatStyle.label)
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title)
            Text(text)
                .font(.body)
                .foregroundStyle(NorthstarChatStyle.text)
                .northstarReadingStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "2026-10-13" → "Oct 13"
    private static func day(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: iso) else { return iso }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }
}
