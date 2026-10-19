import SwiftUI

// 💛 Good Listener: the one-time safety notice (Settings → Modules) and the "Save to My Journal" card
// under a reply. Nothing is saved until the person taps Save.

struct ListenerNoticeView: View {
    var onUnderstand: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                    .accessibilityHidden(true)
                Text("Good Listener")
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Text("Northstar is here to listen and help you put your thoughts into words. It isn't a therapist and can't diagnose or treat conditions.")
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)

                point("ear", "Find Good Listener anytime: tap Listen (the ear), just above the text field in Chat.")
                point("lock.shield", "You decide what is saved and what is shared. Your journal stays on this phone.")
                point("phone.fill", "If you're ever in immediate danger, call emergency services.")
                point("message.fill", "In the United States, you can also call or text 988 for immediate support.")

                Button(action: onUnderstand) {
                    Text("I Understand")
                        .font(.headline)
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Button("Not now", action: onCancel)
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundStyle(NorthstarChatStyle.text)
            .padding(28)
        }
        .background(NorthstarChatStyle.background.ignoresSafeArea())
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(NorthstarChatStyle.linkBlue)
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Save to My Journal?" under a reply. The person can change the title first.
struct JournalOfferCard: View {
    let entry: NorthstarInsight.JournalEntry

    private enum Step: Equatable { case offer, saved, dismissed }
    @State private var step: Step = .offer
    @State private var title = ""
    @State private var showAll = false

    var body: some View {
        if step != .dismissed {
            VStack(alignment: .leading, spacing: 12) {
                Label("Journal entry", systemImage: "book.closed")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NorthstarChatStyle.label)

                if step == .offer {
                    TextField("Title", text: $title)
                        .font(.headline)
                        .foregroundStyle(NorthstarChatStyle.text)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(NorthstarChatStyle.cardStrong))
                        .accessibilityLabel("Entry title")
                } else {
                    Text(title).font(.headline).foregroundStyle(NorthstarChatStyle.text)
                }

                Text(entry.text)
                    .font(.body)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .lineLimit(showAll ? nil : 5)
                    .fixedSize(horizontal: false, vertical: true)
                if entry.text.count > 240 {
                    Button(showAll ? "Show less" : "Show all") { showAll.toggle() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .frame(minHeight: 44)
                }

                switch step {
                case .offer:
                    HStack(spacing: 10) {
                        Button {
                            JournalStore.shared.add(title: title, text: entry.text)
                            step = .saved
                            AccessibilityNotification.Announcement("Saved to My Journal").post()
                        } label: {
                            Text("Save to My Journal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                        }
                        Button {
                            step = .dismissed
                        } label: {
                            Text("Not now")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.text)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().strokeBorder(NorthstarChatStyle.stroke))
                        }
                    }
                    .buttonStyle(.plain)
                    Text("Saved only on this phone.")
                        .font(.caption)
                        .foregroundStyle(NorthstarChatStyle.label)
                case .saved:
                    Label("Saved to My Journal", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.savedGreen)
                case .dismissed:
                    EmptyView()
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke))
            .accessibilityElement(children: .contain)
            .onAppear { if title.isEmpty { title = entry.title } }
        }
    }
}
