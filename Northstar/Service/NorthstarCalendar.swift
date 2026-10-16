import Foundation
import EventKit

// 🗓 Calendar and Reminders, using the iPhone's own apps (so alerts work even when Northstar is closed).
// Northstar never adds anything by itself: only when the person taps Add on a card.
// The calendar is read only when they ask about their schedule, and only the next 7 days.

@MainActor
final class NorthstarCalendar {
    static let shared = NorthstarCalendar()
    private let store = EKEventStore()

    enum AddError: LocalizedError {
        case noAccess(String), badDate
        var errorDescription: String? {
            switch self {
            case .noAccess(let app): return "Northstar needs access to \(app). You can allow it in iPhone Settings › Northstar."
            case .badDate: return "That date didn't look right. Please try again."
            }
        }
    }

    /// Does this message ask about their schedule? ("what's on my calendar", "am I free Friday")
    static func asksAboutSchedule(_ text: String) -> Bool {
        let t = text.lowercased()
        let words = ["my schedule", "my calendar", "my agenda", "my day", "my week", "appointments",
                     "am i free", "am i busy", "what do i have", "what's on", "whats on", "what is on",
                     "anything planned", "what have i got"]
        return words.contains { t.contains($0) }
    }

    /// Next 7 days, for the brain. nil if they haven't allowed Calendar.
    func upcoming() async -> [NorthstarEngineClient.CalendarLine]? {
        guard await hasEventAccess() else { return nil }
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
            .prefix(30)
        return events.map { e in
            NorthstarEngineClient.CalendarLine(
                title: e.title ?? "Event",
                when: Self.whenText(e.startDate, allDay: e.isAllDay),
                location: (e.location?.isEmpty == false) ? e.location : nil
            )
        }
    }

    /// Adds the card's event or reminder. Returns where it went ("Calendar" or "Reminders").
    func add(_ s: NorthstarInsight.Schedule) async throws -> String {
        guard let start = s.start else { throw AddError.badDate }
        if s.isEvent {
            guard await hasEventAccess() else { throw AddError.noAccess("Calendars") }
            let e = EKEvent(eventStore: store)
            e.title = s.title
            e.startDate = start
            e.endDate = start.addingTimeInterval(TimeInterval((s.minutes ?? 60) * 60))
            e.location = s.location
            e.calendar = store.defaultCalendarForNewEvents
            e.addAlarm(EKAlarm(relativeOffset: -TimeInterval((s.alertMinutes ?? 30) * 60)))
            if let rule = Self.rule(s.repeatRule) { e.addRecurrenceRule(rule) }
            try store.save(e, span: .futureEvents)
            return "Calendar"
        } else {
            guard await hasReminderAccess() else { throw AddError.noAccess("Reminders") }
            let r = EKReminder(eventStore: store)
            r.title = s.title
            r.calendar = store.defaultCalendarForNewReminders()
            r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: start)
            r.addAlarm(EKAlarm(absoluteDate: start))
            if let rule = Self.rule(s.repeatRule) { r.addRecurrenceRule(rule) }
            try store.save(r, commit: true)
            return "Reminders"
        }
    }

    // MARK: - Access (the iPhone asks once; after that it remembers their answer)

    private func hasEventAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return true
        case .notDetermined: return (try? await store.requestFullAccessToEvents()) ?? false
        default: return false
        }
    }

    private func hasReminderAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: return true
        case .notDetermined: return (try? await store.requestFullAccessToReminders()) ?? false
        default: return false
        }
    }

    private static func rule(_ r: String?) -> EKRecurrenceRule? {
        let f: EKRecurrenceFrequency
        switch r {
        case "daily": f = .daily
        case "weekly": f = .weekly
        case "monthly": f = .monthly
        case "yearly": f = .yearly
        default: return nil
        }
        return EKRecurrenceRule(recurrenceWith: f, interval: 1, end: nil)
    }

    /// "Today 2:00 PM", "Tomorrow all day", "Mon, Oct 19 9:30 AM"
    private static func whenText(_ d: Date, allDay: Bool) -> String {
        let cal = Calendar.current
        let day = cal.isDateInToday(d) ? "Today" : cal.isDateInTomorrow(d) ? "Tomorrow"
            : d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return allDay ? "\(day) all day" : "\(day) \(d.formatted(date: .omitted, time: .shortened))"
    }
}
