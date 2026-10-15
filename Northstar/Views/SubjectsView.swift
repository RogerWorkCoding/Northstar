import SwiftUI

// 📁 Projects (star menu): the subjects Northstar keeps for the person, one card each —
// the goal, the decisions so far and the next step. Northstar offers to keep a project
// in chat ("Keep this?"); this screen shows them. Tap one to see it, mark it done or delete it.

struct SubjectsView: View {
    @State private var active: [Subject] = []
    @State private var done: [Subject] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var opened: Subject?
    @State private var showDone = false

    private let service = SubjectsService()

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            if !loaded {
                ProgressView().tint(NorthstarChatStyle.text)
            } else if failed {
                message(icon: "exclamationmark.triangle", title: "Couldn't load your projects",
                        detail: "Check your connection and try again.")
            } else if active.isEmpty && done.isEmpty {
                message(icon: "folder", title: "No projects yet",
                        detail: "When you work on something with Northstar, like a garden or a first spoon, it offers to keep it as a project. Kept projects show here with their goal and next step.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !active.isEmpty {
                            header("Active")
                            ForEach(active) { card($0) }
                        }
                        if !done.isEmpty {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { showDone.toggle() }
                            } label: {
                                HStack(spacing: 6) {
                                    header("Done · \(done.count)")
                                    Image(systemName: showDone ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(NorthstarChatStyle.label)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            .accessibilityLabel(showDone ? "Hide done projects" : "Show \(done.count) done projects")
                            if showDone { ForEach(done) { card($0) } }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await load() } }
        .sheet(item: $opened) { subject in
            SubjectDetailSheet(
                subject: subject,
                onDone: { Task { try? await service.markDone(id: subject.id); await load() }; opened = nil },
                onDelete: { Task { try? await service.delete(id: subject.id); await load() }; opened = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func card(_ subject: Subject) -> some View {
        let isDone = subject.status == "done"
        return Button { opened = subject } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "scope")
                    .font(.title3)
                    .foregroundStyle(isDone ? NorthstarChatStyle.savedGreen : NorthstarChatStyle.linkBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.text)
                    if let goal = subject.goal, !goal.isEmpty {
                        Text("Goal: \(goal)")
                            .font(.footnote)
                            .foregroundStyle(NorthstarChatStyle.soft)
                            .lineLimit(2)
                    }
                    if !isDone, let next = subject.nextStep, !next.isEmpty {
                        Text("Next: \(next)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .lineLimit(2)
                    }
                    if !subject.decisions.isEmpty {
                        Text(subject.decisions.count == 1 ? "1 decision" : "\(subject.decisions.count) decisions")
                            .font(.caption)
                            .foregroundStyle(NorthstarChatStyle.label)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.label)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isDone ? NorthstarChatStyle.card.opacity(0.5) : NorthstarChatStyle.card))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this project")
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(NorthstarChatStyle.label)
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(NorthstarChatStyle.label)
            Text(title).font(.headline).foregroundStyle(NorthstarChatStyle.text)
            Text(detail).font(.subheadline).foregroundStyle(NorthstarChatStyle.soft).multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func load() async {
        do {
            let all = try await service.all()
            active = all.filter { $0.status != "done" }
            done = all.filter { $0.status == "done" }
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }
}
