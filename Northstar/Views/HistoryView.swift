import SwiftUI

// History: your saved chats, newest first, grouped by day.
// Tap one to keep going where you left off; swipe to delete.

struct HistoryView: View {
    var onOpen: (UUID) -> Void = { _ in }
    var onDeleted: (UUID) -> Void = { _ in }

    @State private var chats: [ChatSummary] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var deleteFailed = false

    private let service = ChatsService()

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()

            if !loaded {
                ProgressView().tint(NorthstarChatStyle.text)
            } else if failed {
                message(icon: "exclamationmark.triangle", title: "Couldn't load your chats",
                        detail: "Check your connection and try again.")
            } else if chats.isEmpty {
                message(icon: "clock.arrow.circlepath", title: "No saved chats yet",
                        detail: "Chats are kept here while memory is on. Start one from the chat screen.")
            } else {
                list
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Couldn't delete that chat", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    private var list: some View {
        List {
            ForEach(groups, id: \.title) { group in
                Section {
                    ForEach(group.chats) { chat in
                        Button { onOpen(chat.id) } label: { row(chat) }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { Task { await delete(chat) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(group.title.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ chat: ChatSummary) -> some View {
        HStack(spacing: 10) {
            Text(chat.title)
                .font(.body)
                .foregroundStyle(NorthstarChatStyle.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(Calendar.current.isDateInToday(chat.updatedAt) || Calendar.current.isDateInYesterday(chat.updatedAt)
                 ? chat.updatedAt.formatted(.dateTime.hour().minute())
                 : chat.updatedAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 50)
        .frostedCapsule()
        .contentShape(Capsule())
        .accessibilityHint("Opens this chat")
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(NorthstarChatStyle.label)
            Text(title).font(.headline).foregroundStyle(NorthstarChatStyle.text)
            Text(detail).font(.subheadline).foregroundStyle(NorthstarChatStyle.soft).multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // Today / Yesterday / Earlier
    private var groups: [(title: String, chats: [ChatSummary])] {
        let cal = Calendar.current
        let today = chats.filter { cal.isDateInToday($0.updatedAt) }
        let yesterday = chats.filter { cal.isDateInYesterday($0.updatedAt) }
        let earlier = chats.filter { !cal.isDateInToday($0.updatedAt) && !cal.isDateInYesterday($0.updatedAt) }
        return [("Today", today), ("Yesterday", yesterday), ("Earlier", earlier)].filter { !$0.1.isEmpty }
    }

    private func load() async {
        do {
            chats = try await service.list()
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }

    private func delete(_ chat: ChatSummary) async {
        do {
            try await service.delete(id: chat.id)
            chats.removeAll { $0.id == chat.id }
            onDeleted(chat.id)
        } catch {
            deleteFailed = true
        }
    }
}
