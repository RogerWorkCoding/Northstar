import SwiftUI
import EventKit

// ✦ Tap the star: three orbs for Northstar itself. Settings (its own screen), Connections and Brain level
// (both open right here in the Discovery panel, so nobody leaves Discovery to change them).

/// How hard Northstar thinks. Sent to the brain with every chat message ("fast" | "smart" | "deep").
nonisolated enum NorthstarBrainLevel: String, CaseIterable, Identifiable, Sendable {
    case fast, smart, deep
    var id: String { rawValue }
    static let storageKey = "ns.brainLevel"
    static var current: NorthstarBrainLevel {
        NorthstarBrainLevel(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .smart
    }

    var title: String {
        switch self {
        case .fast: "Fast"
        case .smart: "Smart"
        case .deep: "Deep"
        }
    }
    var symbol: String {
        switch self {
        case .fast: "hare"
        case .smart: "sparkles"
        case .deep: "brain.head.profile"
        }
    }
    var detail: String {
        switch self {
        case .fast: "Quick answers, every time."
        case .smart: "Quick for everyday questions. Thinks it through (Deep Think) on hard ones. Recommended."
        case .deep: "Thinks it through on most questions. Slower, and uses your Deep Think answers for the day sooner."
        }
    }
}

/// Brain level, chosen right in Discovery.
struct BrainLevelPanelContent: View {
    @AppStorage(NorthstarBrainLevel.storageKey) private var level = NorthstarBrainLevel.smart.rawValue
    private let gold = Color(red: 1.0, green: 0.84, blue: 0.55)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How hard should Northstar think?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            ForEach(NorthstarBrainLevel.allCases) { option in
                let on = level == option.rawValue
                Button {
                    level = option.rawValue
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                            .foregroundStyle(on ? gold : .white.opacity(0.8))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title).font(.headline).foregroundStyle(.white)
                            Text(option.detail)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(on ? gold : .white.opacity(0.4))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(on ? 0.14 : 0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(on ? gold.opacity(0.8) : .white.opacity(0.15), lineWidth: on ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
            Text("Deep Think: up to 15 thought-through answers a day. Help in a crisis always gets the best answer and never counts.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Connections, right in Discovery: real ones can be connected here; future ones say "Soon".
struct ConnectionsPanelContent: View {
    @State private var tick = 0          // refreshes the statuses after a connect
    @State private var working: String?
    private let gold = Color(red: 1.0, green: 0.84, blue: 0.55)

    private struct Item: Identifiable {
        let id: String, title: String, symbol: String, helps: String
        let entity: EKEntityType?        // nil = not built yet ("Soon")
    }
    private let items: [Item] = [
        Item(id: "calendar", title: "Calendar", symbol: "calendar", helps: "Plan around your real day", entity: .event),
        Item(id: "reminders", title: "Reminders", symbol: "checklist", helps: "Turn plans into reminders", entity: .reminder),
        Item(id: "contacts", title: "Contacts", symbol: "person.2", helps: "Message people by name", entity: nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect your apps and Northstar can help more.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            ForEach(items) { item in row(item) }
            Text("Northstar only reads what you allow, only when you ask.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .id(tick)
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.title3)
                .foregroundStyle(gold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.headline).foregroundStyle(.white)
                Text(item.helps).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            status(item)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06)))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func status(_ item: Item) -> some View {
        if let entity = item.entity {
            switch EKEventStore.authorizationStatus(for: entity) {
            case .fullAccess:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.6, green: 0.9, blue: 0.7))
            case .notDetermined, .writeOnly:
                Button {
                    working = item.id
                    Task {
                        _ = await NorthstarCalendar.shared.connect(item.id)
                        working = nil
                        tick += 1
                    }
                } label: {
                    Text(working == item.id ? "\u{2026}" : "Connect")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.06, green: 0.08, blue: 0.18))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(gold))
                }
                .buttonStyle(.plain)
                .disabled(working != nil)
                .accessibilityHint("iPhone asks for your permission")
            default:
                Text("Off in iPhone Settings")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.trailing)
            }
        } else {
            Text("Soon")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
        }
    }
}
