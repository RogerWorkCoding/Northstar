import SwiftUI

// 🛎 Concierge (the bell beside the ask bar on Home).
// Pick what you need and Northstar starts on it: a few good options, a map, and buttons to
// reserve, call or get a ride. Northstar shows options; you choose. It never books or pays.

struct ConciergeView: View {
    /// Starts a chat with this request.
    var onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct Service: Identifiable {
        let id: String
        let title: String
        let icon: String
        let request: String
    }

    private let services: [Service] = [
        .init(id: "dinner", title: "Dinner", icon: "fork.knife",
              request: "Find me a good place for dinner near me."),
        .init(id: "fitness", title: "Fitness", icon: "figure.yoga",
              request: "Find a fitness class near me this week."),
        .init(id: "fun", title: "Fun", icon: "sparkles",
              request: "What's something fun to do near me this weekend?"),
        .init(id: "rides", title: "Rides", icon: "car",
              request: "Help me get a ride somewhere."),
        .init(id: "errands", title: "Errands", icon: "bag",
              request: "Help me with an errand nearby, like the nearest open pharmacy or store."),
        .init(id: "gifts", title: "Gifts", icon: "gift",
              request: "Help me find a good gift."),
    ]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What do you need?")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(NorthstarChatStyle.text)
                            .accessibilityAddTraits(.isHeader)
                        Text("Pick one and I'll find a few good options. You choose.")
                            .font(.body)
                            .foregroundStyle(NorthstarChatStyle.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(services) { service in
                            Button {
                                onPick(service.request)
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: service.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                                    Text(service.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(NorthstarChatStyle.text)
                                }
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(service.request)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("OR JUST ASK")
                            .font(.caption.weight(.semibold))
                            .tracking(2)
                            .foregroundStyle(NorthstarChatStyle.label)
                        Text("Type anything in the ask bar, like \u{201C}Dinner Saturday for 4, somewhere quiet.\u{201D}")
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label("Northstar never books or pays without you.", systemImage: "hand.raised")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack {
            Label {
                Text("Concierge").font(.headline)
            } icon: {
                Image(systemName: "bell").foregroundStyle(NorthstarChatStyle.starGold)
            }
            .foregroundStyle(NorthstarChatStyle.text)
            Spacer()
            Button("Close") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(NorthstarChatStyle.linkBlue)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.top, 8)
    }
}

#Preview {
    ConciergeView { _ in }
}
