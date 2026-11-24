import Foundation
import SwiftData

enum TaskSize: String, Codable, CaseIterable {
    case s, m, l

    var label: String {
        switch self {
        case .s: return "S"
        case .m: return "M"
        case .l: return "L"
        }
    }
}

enum HabitLogKind: String, Codable {
    case done
    case lowBattery
}

struct TaskStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false
}

/// A to-do. `dayKey == nil` means it sits in the Inbox; `startMinutes == nil` means "anytime that day".
@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var dayKey: Int? = nil
    var startMinutes: Int? = nil
    var minutes: Int = 30
    var sizeRaw: String = "m"
    var priority: Bool = false
    var stepsData: Data = Data()
    var remindBefore: Int? = nil
    var doneAt: Date? = nil
    var doneDayKey: Int? = nil
    var createdAt: Date = Date()
    var plantIndex: Int = 0

    init(title: String, dayKey: Int? = nil, startMinutes: Int? = nil, minutes: Int = 30) {
        self.id = UUID()
        self.title = title
        self.dayKey = dayKey
        self.startMinutes = startMinutes
        self.minutes = minutes
        self.sizeRaw = TaskItem.size(for: minutes).rawValue
        self.createdAt = Date()
        self.plantIndex = Int.random(in: 0..<4)
    }

    var isDone: Bool { doneAt != nil }

    var size: TaskSize {
        get { TaskSize(rawValue: sizeRaw) ?? .m }
        set { sizeRaw = newValue.rawValue }
    }

    var steps: [TaskStep] {
        get { (try? JSONDecoder().decode([TaskStep].self, from: stepsData)) ?? [] }
        set { stepsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var isBig: Bool { priority || minutes >= 60 }

    static func size(for minutes: Int) -> TaskSize {
        if minutes <= 20 { return .s }
        if minutes <= 60 { return .m }
        return .l
    }
}

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 0
    var targetPerWeek: Int = 3
    /// Bit 0 = Monday … bit 6 = Sunday. Days the habit may be done on.
    var daysMask: Int = 127
    var timeMinutes: Int? = nil
    var minutes: Int = 15
    var lowBatteryVersion: String = ""
    var chainAfterID: UUID? = nil
    var paused: Bool = false
    var remind: Bool = true
    var createdAt: Date = Date()
    var order: Int = 0

    init(name: String, colorIndex: Int, targetPerWeek: Int, daysMask: Int = 127, timeMinutes: Int? = nil, minutes: Int = 15) {
        self.id = UUID()
        self.name = name
        self.colorIndex = colorIndex
        self.targetPerWeek = targetPerWeek
        self.daysMask = daysMask
        self.timeMinutes = timeMinutes
        self.minutes = minutes
        self.createdAt = Date()
    }

    func allowed(onWeekday weekday: Int) -> Bool {
        (daysMask >> weekday) & 1 == 1
    }

    var isDaily: Bool { targetPerWeek >= 7 }
}

@Model
final class HabitLog {
    var id: UUID = UUID()
    var habitID: UUID = UUID()
    var dayKey: Int = 0
    var kindRaw: String = HabitLogKind.done.rawValue
    var minuteOfDay: Int = 0

    init(habitID: UUID, dayKey: Int, kind: HabitLogKind, minuteOfDay: Int) {
        self.id = UUID()
        self.habitID = habitID
        self.dayKey = dayKey
        self.kindRaw = kind.rawValue
        self.minuteOfDay = minuteOfDay
    }

    var kind: HabitLogKind { HabitLogKind(rawValue: kindRaw) ?? .done }
}

/// A day the habit doesn't count against its target (holiday, ill). Streaks are kept.
@Model
final class FreezeDay {
    var dayKey: Int = 0
    init(dayKey: Int) { self.dayKey = dayKey }
}

@Model
final class DayCheckin {
    var dayKey: Int = 0
    var battery: Int = 2
    var moodsRaw: String = ""
    var createdAt: Date = Date()

    init(dayKey: Int, battery: Int, moods: [String]) {
        self.dayKey = dayKey
        self.battery = battery
        self.moodsRaw = moods.joined(separator: "|")
        self.createdAt = Date()
    }

    var moods: [String] { moodsRaw.split(separator: "|").map(String.init) }
}

@Model
final class JournalEntry {
    var dayKey: Int = 0
    var text: String = ""
    var createdAt: Date = Date()

    init(dayKey: Int, text: String) {
        self.dayKey = dayKey
        self.text = text
        self.createdAt = Date()
    }
}

/// Pip, shells and everything bought in the shop. One row.
@Model
final class IsleState {
    var shells: Int = 0
    var growth: Int = 0
    var pipName: String = "Pip"
    var bodyColorIndex: Int = 0
    var outfit: String = "none"
    var ownedRaw: String = ""
    var claimedRaw: String = ""
    var focusSessions: Int = 0
    var plannedWeeksRaw: String = ""

    init() {}

    var owned: Set<String> {
        get { Set(ownedRaw.split(separator: ",").map(String.init)) }
        set { ownedRaw = newValue.sorted().joined(separator: ",") }
    }

    var claimed: Set<String> {
        get { Set(claimedRaw.split(separator: ",").map(String.init)) }
        set { claimedRaw = newValue.sorted().joined(separator: ",") }
    }

    var plannedWeeks: Set<Int> {
        get { Set(plannedWeeksRaw.split(separator: ",").compactMap { Int($0) }) }
        set { plannedWeeksRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }
}

/// Planning preferences. One row. Sound and haptic preferences live in UserDefaults (see Feedback).
@Model
final class AppSettings {
    var onboarded: Bool = false
    var capacityWeekday: Int = 420
    var capacityWeekend: Int = 300
    var checkinOn: Bool = true
    var rolloverAsk: Bool = true
    var lastRolloverKey: Int = 0
    var themeRaw: String = "auto"
    var notifStyle: String = "gentle"
    var quietStart: Int = 22 * 60
    var quietEnd: Int = 7 * 60
    var sundayPlanMinutes: Int = 19 * 60
    var calendarOn: Bool = false
    var notificationsOn: Bool = false
    var weekTheme: String = ""
    var weekThemeKey: Int = 0

    init() {}

    func capacity(forWeekday weekday: Int) -> Int {
        weekday >= 5 ? capacityWeekend : capacityWeekday
    }
}

enum IsleSchema {
    static let models: [any PersistentModel.Type] = [
        TaskItem.self, Habit.self, HabitLog.self, FreezeDay.self, DayCheckin.self,
        JournalEntry.self, IsleState.self, AppSettings.self
    ]
}
