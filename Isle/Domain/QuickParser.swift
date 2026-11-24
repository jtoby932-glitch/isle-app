import Foundation

/// Turns "gym tue thu sat 7am 45m" into a habit on three days at 07:00 for 45 minutes.
struct ParsedInput: Equatable {
    var name: String = ""
    var weekdays: [Int] = []      // 0 = Monday
    var dayKey: Int? = nil        // a single dated day ("tomorrow", "fri")
    var startMinutes: Int? = nil
    var minutes: Int? = nil
    var target: Int? = nil
    var isHabit: Bool = false
    var colorIndex: Int = 4

    var chips: [String] {
        var out: [String] = []
        if !name.isEmpty { out.append(name) }
        if weekdays.count == 7 { out.append("Every day") }
        else if weekdays.count == 5 && weekdays == [0, 1, 2, 3, 4] { out.append("Weekdays") }
        else if !weekdays.isEmpty { out.append(weekdays.map { Day.shortNames[$0] }.joined(separator: " · ")) }
        if let s = startMinutes { out.append(Fmt.clock(s)) }
        if let m = minutes { out.append(Fmt.duration(m)) }
        if isHabit { out.append("\(target ?? max(1, weekdays.count == 0 ? 7 : weekdays.count))× a week") }
        if let s = startMinutes { out.append("Remind \(Fmt.clock(s - 15))") }
        return out
    }
}

enum QuickParser {
    static let habitWords: Set<String> = ["gym", "read", "walk", "run", "meditate", "stretch", "journal", "water", "yoga", "swim", "sleep", "bed", "floss", "drink", "workout", "practice", "study", "revise"]
    static let habitColors: [String: Int] = ["gym": 0, "workout": 0, "swim": 0, "read": 1, "study": 1, "revise": 1, "walk": 2, "run": 2, "water": 2, "drink": 2, "meditate": 3, "sleep": 3, "bed": 3, "yoga": 3, "stretch": 3]

    static func parse(_ raw: String, today: Int = Day.today) -> ParsedInput {
        var out = ParsedInput()
        var text = " " + raw.lowercased() + " "

        func take(_ pattern: String) -> [String]? {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
            let ns = text as NSString
            guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
            var groups: [String] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            text = ns.replacingCharacters(in: m.range, with: " ")
            return groups
        }

        var days: [Int] = []
        var everyDay = false
        if take("\\b(daily|every ?day)\\b") != nil { days = Array(0...6); everyDay = true }
        if take("\\bweekdays\\b") != nil { days = [0, 1, 2, 3, 4]; everyDay = true }
        if take("\\bweekends?\\b") != nil { days = [5, 6]; everyDay = true }
        if take("\\btomorrow\\b") != nil { out.dayKey = Day.add(today, days: 1) }
        if take("\\btoday\\b") != nil { out.dayKey = today }

        let names = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        var guardCount = 0
        while guardCount < 10, let g = take("\\b(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)[a-z]*\\b") {
            guardCount += 1
            let k = String(g[1].prefix(3))
            if let i = names.firstIndex(of: k), !days.contains(i) { days.append(i) }
        }
        days.sort()

        if let g = take("\\b(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)\\b") {
            var h = (Int(g[1]) ?? 0) % 12
            if g[3] == "pm" { h += 12 }
            out.startMinutes = h * 60 + (Int(g[2]) ?? 0)
        } else if let g = take("\\b(\\d{1,2}):(\\d{2})\\b") {
            out.startMinutes = (Int(g[1]) ?? 0) * 60 + (Int(g[2]) ?? 0)
        }

        var mins = 0
        if let g = take("\\b(\\d+(?:\\.\\d)?)\\s*(h|hr|hrs|hours?)\\b") { mins += Int((Double(g[1]) ?? 0) * 60) }
        if let g = take("\\b(\\d+)\\s*(m|min|mins|minutes?)\\b") { mins += Int(g[1]) ?? 0 }
        if mins > 0 { out.minutes = mins }

        if let g = take("\\b(\\d)\\s*x\\b") { out.target = Int(g[1]) }

        let cleaned = text
            .replacingOccurrences(of: "\\b(at|on|every|for|and)\\b", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let first = cleaned.split(separator: " ").first.map(String.init) ?? ""
        out.name = cleaned.isEmpty ? "" : cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        out.isHabit = everyDay || days.count > 1 || out.target != nil || habitWords.contains(first)
        out.colorIndex = habitColors[first] ?? 4

        if out.isHabit {
            out.weekdays = days.isEmpty ? Array(0...6) : days
        } else if days.count == 1, out.dayKey == nil {
            // the next occurrence of that weekday, today included
            let wd = Day.weekday(today)
            var diff = days[0] - wd
            if diff < 0 { diff += 7 }
            out.dayKey = Day.add(today, days: diff)
            out.weekdays = days
        } else {
            out.weekdays = days
        }
        return out
    }
}
