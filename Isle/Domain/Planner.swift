import Foundation

/// A calendar event as Isle sees it (read from EventKit, never stored).
struct CalEvent: Identifiable, Hashable {
    var id: String
    var title: String
    var dayKey: Int
    var startMinutes: Int
    var minutes: Int
    var allDay: Bool
}

enum Planner {
    /// Minutes of planned work on a day: tasks + habits allowed that day + timed calendar events.
    static func load(day: Int, tasks: [TaskItem], habits: [Habit], events: [CalEvent], includeDone: Bool = true) -> Int {
        let wd = Day.weekday(day)
        let t = tasks.filter { $0.dayKey == day && (includeDone || !$0.isDone) }.reduce(0) { $0 + $1.minutes }
        let h = habits.filter { !$0.paused && $0.allowed(onWeekday: wd) && $0.timeMinutes != nil }.reduce(0) { $0 + $1.minutes }
        let e = events.filter { $0.dayKey == day && !$0.allDay }.reduce(0) { $0 + $1.minutes }
        return t + h + e
    }

    /// Picks days for unplanned tasks: biggest first, each onto the day with the most room left.
    static func autoPlan(tasks: [TaskItem], days: [Int], loads: [Int: Int], capacity: (Int) -> Int, avoidPast: Bool = true) -> [(TaskItem, Int)] {
        var l = loads
        let today = Day.today
        let candidates = days.filter { !avoidPast || $0 >= today }
        guard !candidates.isEmpty else { return [] }
        var out: [(TaskItem, Int)] = []
        for task in tasks.sorted(by: { $0.minutes > $1.minutes }) {
            var best = candidates[0]
            var bestRatio = Double.greatestFiniteMagnitude
            for d in candidates {
                let cap = max(60, capacity(d))
                let ratio = Double((l[d] ?? 0) + task.minutes) / Double(cap)
                if ratio < bestRatio { bestRatio = ratio; best = d }
            }
            l[best, default: 0] += task.minutes
            out.append((task, best))
        }
        return out
    }

    /// Moves the smallest movable tasks off an overloaded day onto the lightest later days of the week.
    static func fix(day: Int, week: [Int], tasks: [TaskItem], loads: [Int: Int], capacity: (Int) -> Int) -> [(TaskItem, Int)] {
        var l = loads
        let cap = capacity(day)
        var over = (l[day] ?? 0) - cap
        guard over > 0 else { return [] }
        let movable = tasks
            .filter { $0.dayKey == day && !$0.isDone && !$0.priority && $0.startMinutes == nil }
            .sorted { $0.minutes < $1.minutes }
        let targets = week.filter { $0 != day && $0 >= Day.today }
        guard !targets.isEmpty else { return [] }
        var out: [(TaskItem, Int)] = []
        for task in movable where over > 0 {
            let best = targets.min { (a, b) -> Bool in
                Double((l[a] ?? 0) + task.minutes) / Double(max(60, capacity(a))) < Double((l[b] ?? 0) + task.minutes) / Double(max(60, capacity(b)))
            } ?? targets[0]
            l[best, default: 0] += task.minutes
            l[day, default: 0] -= task.minutes
            over -= task.minutes
            out.append((task, best))
        }
        return out
    }

    /// Largest free gap (minutes) between now and the end of the planning day, given timed items.
    static func freeGap(day: Int, timed: [(start: Int, minutes: Int)], from: Int, dayEnd: Int = 21 * 60) -> (start: Int, length: Int)? {
        let blocks = timed.sorted { $0.start < $1.start }
        var cursor = from
        var best: (Int, Int)? = nil
        for b in blocks {
            if b.start > cursor {
                let len = b.start - cursor
                if best == nil || len > best!.1 { best = (cursor, len) }
            }
            cursor = max(cursor, b.start + b.minutes)
        }
        if dayEnd > cursor {
            let len = dayEnd - cursor
            if best == nil || len > best!.1 { best = (cursor, len) }
        }
        guard let b = best, b.1 >= 45 else { return nil }
        let start = ((b.0 + 14) / 15) * 15
        return (start, b.1 - (start - b.0))
    }
}

enum Rewards {
    static func shells(for task: TaskItem) -> Int { task.isBig ? 20 : 10 }
    static func shells(forHabitOnLowBattery low: Bool) -> Int { low ? 20 : 10 }
    static let focus = 20
    static let planning = 20

    /// Level n needs 50·n·(n+1) growth in total.
    static func level(forGrowth g: Int) -> Int {
        var n = 1
        while 50 * n * (n + 1) <= g { n += 1 }
        return n
    }

    static func progress(forGrowth g: Int) -> (have: Int, need: Int) {
        let n = level(forGrowth: g)
        let floor = 50 * (n - 1) * n
        let ceil = 50 * n * (n + 1)
        return (g - floor, ceil - floor)
    }
}
