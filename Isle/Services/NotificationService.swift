import Foundation
import UserNotifications

/// Local notifications only. Rebuilt from scratch whenever the plan changes (cheap: at most a few dozen).
enum NotificationService {
    static let center = UNUserNotificationCenter.current()

    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func registerCategories() {
        let done = UNNotificationAction(identifier: "DONE", title: "Done", options: [])
        let later = UNNotificationAction(identifier: "LATER", title: "Later", options: [])
        let open = UNNotificationAction(identifier: "OPEN", title: "Open Isle", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "ITEM", actions: [done, later], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "PLAN", actions: [open], intentIdentifiers: [], options: [])
        ])
    }

    struct Planned {
        var id: String
        var title: String
        var body: String
        var date: Date
        var category: String
        var important: Bool
    }

    @MainActor
    static func reschedule(tasks: [TaskItem], habits: [Habit], settings: AppSettings, pipName: String) {
        guard settings.notificationsOn else {
            center.removeAllPendingNotificationRequests()
            return
        }
        center.removeAllPendingNotificationRequests()
        let now = Date()
        let today = Day.today
        var items: [Planned] = []

        func quiet(_ minutes: Int) -> Bool {
            let s = settings.quietStart, e = settings.quietEnd
            if s > e { return minutes >= s || minutes < e }
            return minutes >= s && minutes < e
        }

        for offset in 0..<7 {
            let day = Day.add(today, days: offset)
            var dayItems: [Planned] = []
            for t in tasks where t.dayKey == day && !t.isDone {
                guard let start = t.startMinutes, let before = t.remindBefore else { continue }
                let at = start - before
                if quiet(at) { continue }
                let date = Day.dateAt(day, minutes: at)
                if date < now { continue }
                dayItems.append(Planned(id: "task-\(t.id)-\(day)", title: t.title,
                                        body: before > 0 ? "Starts at \(Fmt.clock(start)) · \(Fmt.duration(t.minutes))" : "Starting now · \(Fmt.duration(t.minutes))",
                                        date: date, category: "ITEM", important: true))
            }
            if settings.notifStyle != "essentials" {
                let wd = Day.weekday(day)
                for h in habits where !h.paused && h.remind && h.allowed(onWeekday: wd) {
                    guard let time = h.timeMinutes, !quiet(time) else { continue }
                    let date = Day.dateAt(day, minutes: time)
                    if date < now { continue }
                    dayItems.append(Planned(id: "habit-\(h.id)-\(day)", title: "\(h.name)?",
                                            body: "You usually do this around now. \(pipName) saved your spot.",
                                            date: date, category: "ITEM", important: false))
                }
            }
            if settings.notifStyle == "gentle" {
                let important = dayItems.filter { $0.important }
                let rest = dayItems.filter { !$0.important }
                dayItems = Array((important + rest).prefix(3))
            }
            items += dayItems
        }

        struct Pending { var id: String; var content: UNMutableNotificationContent; var trigger: UNNotificationTrigger }
        var schedule: [Pending] = []
        for p in items.prefix(56) {
            let c = UNMutableNotificationContent()
            c.title = p.title
            c.body = p.body
            c.sound = .default
            c.categoryIdentifier = p.category
            let comps = Day.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: p.date)
            schedule.append(Pending(id: p.id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }

        // Sunday planning, weekly
        let plan = UNMutableNotificationContent()
        plan.title = "Plan your week with \(pipName)"
        plan.body = "Ten minutes now makes the whole week lighter."
        plan.sound = .default
        plan.categoryIdentifier = "PLAN"
        var sunday = DateComponents()
        sunday.weekday = 1
        sunday.hour = settings.sundayPlanMinutes / 60
        sunday.minute = settings.sundayPlanMinutes % 60
        schedule.append(Pending(id: "sunday-plan", content: plan, trigger: UNCalendarNotificationTrigger(dateMatching: sunday, repeats: true)))

        if settings.checkinOn && settings.notifStyle != "essentials" {
            let c = UNMutableNotificationContent()
            c.title = "How's your battery?"
            c.body = "Ten-second check-in and \(pipName) will shape today around it."
            c.categoryIdentifier = "PLAN"
            var morning = DateComponents()
            morning.hour = 8
            morning.minute = 5
            schedule.append(Pending(id: "morning-checkin", content: c, trigger: UNCalendarNotificationTrigger(dateMatching: morning, repeats: true)))
        }

        for s in schedule {
            center.add(UNNotificationRequest(identifier: s.id, content: s.content, trigger: s.trigger))
        }
    }

    static func scheduleFocusEnd(at date: Date, title: String) {
        let c = UNMutableNotificationContent()
        c.title = "Focus done"
        c.body = "Nice session on \"\(title)\". Take five."
        c.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: "focus-end", content: c, trigger: trigger))
    }

    static func cancelFocusEnd() {
        center.removePendingNotificationRequests(withIdentifiers: ["focus-end"])
    }
}
