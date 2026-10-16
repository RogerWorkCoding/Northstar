import SwiftUI

// 🗓 "Add to Calendar?" card under a reply. Nothing is added until they tap Add.

struct ScheduleCard: View {
    let schedule: NorthstarInsight.Schedule

    private enum State: Equatable { case offer, adding, added(String), dismissed, failed(String) }
    @SwiftUI.State private var state: State = .offer

    var body: some View {
        if state != .dismissed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: schedule.isEvent ? "calendar" : "checklist")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule.title)
                            .font(.headline)
                            .foregroundStyle(NorthstarChatStyle.text)
                        Text(schedule.whenText)
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.soft)
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(NorthstarChatStyle.label)
                    }
                    Spacer(minLength: 0)
                }

                switch state {
                case .offer, .adding:
                    HStack(spacing: 10) {
                        Button {
                            add()
                        } label: {
                            Text(state == .adding ? "Adding…" : "Add")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(NorthstarChatStyle.primaryFill))
                        }
                        .disabled(state == .adding)
                        Button {
                            state = .dismissed
                        } label: {
                            Text("Not now")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.text)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().strokeBorder(NorthstarChatStyle.stroke))
                        }
                    }
                    .buttonStyle(.plain)
                case .added(let place):
                    Label("Added to \(place)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.savedGreen)
                case .failed(let why):
                    Text(why)
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.warning)
                case .dismissed:
                    EmptyView()
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke))
            .accessibilityElement(children: .contain)
        }
    }

    /// "Calendar · alert 30 min before" / "Reminders · repeats weekly"
    private var detail: String {
        var parts = [schedule.isEvent ? "Calendar" : "Reminders"]
        if schedule.isEvent, let a = schedule.alertMinutes, a > 0 {
            parts.append(a >= 60 && a % 60 == 0 ? "alert \(a / 60) hr before" : "alert \(a) min before")
        }
        if let loc = schedule.location, !loc.isEmpty { parts.append(loc) }
        if let r = schedule.repeatRule { parts.append("repeats \(r)") }
        return parts.joined(separator: " · ")
    }

    private func add() {
        state = .adding
        Task {
            do {
                let place = try await NorthstarCalendar.shared.add(schedule)
                state = .added(place)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
