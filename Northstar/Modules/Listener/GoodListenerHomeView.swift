import SwiftUI

// 👂 Good Listener's own door (like the Concierge bell): the small "Listen" button just above the Chat text
// field opens this. Shown only when Good Listener is switched on (Settings → Modules).
// Three calm choices: talk, write privately, or prepare notes for a counselor. Crisis help is always here.

struct GoodListenerHomeView: View {
    var onTalk: () -> Void
    var onJournal: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "ear")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(NorthstarChatStyle.starGold)
                        .accessibilityHidden(true)
                    Text("Good Listener")
                        .font(.system(size: 28, weight: .light))
                        .accessibilityAddTraits(.isHeader)
                }
                Text("I'm here to listen. Say as much or as little as you like.")
                    .font(.title3)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)

                choice("bubble.left.and.text.bubble.right", "Talk it through",
                       "I'll listen first and ask one gentle question at a time.") {
                    dismiss()
                    onTalk()
                }
                choice("book.closed", "Write in my journal",
                       "Private, on this phone only.") {
                    dismiss()
                    onJournal()
                }
                NavigationLink {
                    CounselorNotesView()
                } label: {
                    row("doc.text", "Notes for my counselor", "Turn journal entries into notes you can share.")
                }
                .buttonStyle(.plain)

                // Help right now, always one tap away.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Need help right now?")
                        .font(.headline)
                    HStack(spacing: 10) {
                        helpLink("Call 988", "phone.fill", "tel:988")
                        helpLink("Text 988", "message.fill", "sms:988")
                    }
                    Text("In danger right now? Call 911.")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.soft)
                }
                .padding(.top, 6)

                Text("Northstar isn't a therapist and can't diagnose or treat.")
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
            }
            .foregroundStyle(NorthstarChatStyle.text)
            .padding(24)
        }
        .background(NorthstarChatStyle.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
    }

    private func choice(_ symbol: String, _ title: String, _ note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { row(symbol, title, note) }
            .buttonStyle(.plain)
    }

    private func row(_ symbol: String, _ title: String, _ note: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(NorthstarChatStyle.linkBlue)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(note).font(.subheadline).foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.label)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(minHeight: 64)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func helpLink(_ title: String, _ symbol: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(NorthstarChatStyle.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
        }
    }
}
