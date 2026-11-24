import Foundation

/// Days are stored as Int keys like 20261123 so they never shift with time zones.
enum Day {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "en_GB")
        c.timeZone = TimeZone.current
        return c
    }()

    static let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let longNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func key(_ date: Date) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    static func date(_ key: Int) -> Date {
        var c = DateComponents()
        c.year = key / 10000
        c.month = (key / 100) % 100
        c.day = key % 100
        c.hour = 12
        return calendar.date(from: c) ?? Date()
    }

    static var today: Int { key(Date()) }

    static func add(_ key: Int, days: Int) -> Int {
        let d = calendar.date(byAdding: .day, value: days, to: date(key)) ?? date(key)
        return Day.key(d)
    }

    /// 0 = Monday … 6 = Sunday
    static func weekday(_ key: Int) -> Int {
        let w = calendar.component(.weekday, from: date(key)) // 1 = Sunday
        return (w + 5) % 7
    }

    static func weekStart(_ key: Int) -> Int {
        add(key, days: -weekday(key))
    }

    static func week(_ startKey: Int) -> [Int] {
        (0..<7).map { add(startKey, days: $0) }
    }

    static func weekNumber(_ key: Int) -> Int {
        calendar.component(.weekOfYear, from: date(key))
    }

    static func shortName(_ key: Int) -> String { shortNames[weekday(key)] }
    static func longName(_ key: Int) -> String { longNames[weekday(key)] }
    static func dayNumber(_ key: Int) -> Int { key % 100 }
    static func monthName(_ key: Int) -> String { months[max(0, min(11, (key / 100) % 100 - 1))] }

    static func title(_ key: Int) -> String { "\(longName(key)) \(dayNumber(key))" }
    static func dayMonth(_ key: Int) -> String { "\(dayNumber(key)) \(monthName(key))" }

    static func weekRange(_ startKey: Int) -> String {
        let end = add(startKey, days: 6)
        if monthName(startKey) == monthName(end) {
            return "\(dayNumber(startKey))–\(dayNumber(end)) \(monthName(end))"
        }
        return "\(dayMonth(startKey)) – \(dayMonth(end))"
    }

    static func relative(_ key: Int) -> String {
        let t = today
        if key == t { return "Today" }
        if key == add(t, days: 1) { return "Tomorrow" }
        if key == add(t, days: -1) { return "Yesterday" }
        return "\(shortName(key)) \(dayNumber(key))"
    }

    static var minuteOfDay: Int {
        let c = calendar.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func dateAt(_ key: Int, minutes: Int) -> Date {
        var c = DateComponents()
        c.year = key / 10000
        c.month = (key / 100) % 100
        c.day = key % 100
        c.hour = minutes / 60
        c.minute = minutes % 60
        return calendar.date(from: c) ?? Date()
    }
}

enum Fmt {
    static func duration(_ minutes: Int) -> String {
        let m = max(0, minutes)
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r)m" }
        if r == 0 { return "\(h)h" }
        return "\(h)h \(r)m"
    }

    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func shells(_ n: Int) -> String { "\(n)" }
}
