import EventKit
import Observation
import SwiftUI

/// Reads calendar events (read-only). Never copies them into Isle's store.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    var authorized: Bool = false
    var revision: Int = 0
    @ObservationIgnored private var cache: [Int: [CalEvent]] = [:]

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorized = status == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            let ok = try await store.requestFullAccessToEvents()
            authorized = ok
            invalidate()
            return ok
        } catch {
            authorized = false
            return false
        }
    }

    func invalidate() {
        cache.removeAll()
        revision += 1
    }

    func events(for day: Int, enabled: Bool) -> [CalEvent] {
        guard enabled, authorized else { return [] }
        if let c = cache[day] { return c }
        let start = Day.dateAt(day, minutes: 0)
        let end = Day.dateAt(Day.add(day, days: 1), minutes: 0)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let raw = store.events(matching: predicate)
        let cal = Day.calendar
        let out: [CalEvent] = raw.map { e in
            let s = max(e.startDate ?? start, start)
            let f = min(e.endDate ?? s, end)
            let comps = cal.dateComponents([.hour, .minute], from: s)
            let startMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            let mins = max(5, Int(f.timeIntervalSince(s) / 60))
            return CalEvent(id: (e.eventIdentifier ?? UUID().uuidString) + "-\(day)",
                            title: e.title ?? "Event",
                            dayKey: day,
                            startMinutes: startMin,
                            minutes: mins,
                            allDay: e.isAllDay)
        }
        .sorted { $0.startMinutes < $1.startMinutes }
        cache[day] = out
        return out
    }

    func events(for days: [Int], enabled: Bool) -> [CalEvent] {
        days.flatMap { events(for: $0, enabled: enabled) }
    }
}
