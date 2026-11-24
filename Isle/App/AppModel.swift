import SwiftUI
import SwiftData
import Observation

enum MainTab: Hashable {
    case today, week, lists, habits, isle
}

/// Where a quick-add opened from: a day and maybe a time on the timeline.
struct QuickAddPreset: Equatable {
    var day: Int?
    var start: Int?
}

/// Screen-level state shared across tabs: which sheets are open, the toast, the undo action.
@MainActor
@Observable
final class AppModel {
    var tab: MainTab = .today
    var showQuickAdd = false
    var quickAddPreset: QuickAddPreset? = nil
    var showRoutines = false
    var editingTask: TaskItem? = nil
    var showCheckin = false
    var focusTask: TaskItem? = nil
    var showFocus = false
    var showDayComplete = false
    var showSunday = false
    var showSearch = false
    var showSettings = false
    var showShop = false
    var openHabit: Habit? = nil
    var toast: ToastData? = nil
    var pipCheer = false

    @ObservationIgnored private var undoAction: (() -> Void)? = nil
    @ObservationIgnored private var cheerToken = 0

    func showToast(_ text: String, undo: (() -> Void)? = nil) {
        undoAction = undo
        let t = ToastData(text: text, canUndo: undo != nil)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { toast = t }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, self.toast?.id == t.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
        }
    }

    func runUndo() {
        undoAction?()
        undoAction = nil
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
    }

    /// Opens quick add, optionally already set to a day and time.
    func quickAdd(day: Int? = nil, start: Int? = nil) {
        quickAddPreset = QuickAddPreset(day: day, start: start)
        showQuickAdd = true
    }

    func cheer() {
        cheerToken += 1
        let token = cheerToken
        pipCheer = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard let self, self.cheerToken == token else { return }
            self.pipCheer = false
        }
    }
}

/// All writes go through here so rewards, sounds and notifications stay consistent.
@MainActor
struct Store {
    let context: ModelContext

    func settings() -> AppSettings {
        if let s = try? context.fetch(FetchDescriptor<AppSettings>()).first { return s }
        let s = AppSettings()
        context.insert(s)
        return s
    }

    func isle() -> IsleState {
        if let s = try? context.fetch(FetchDescriptor<IsleState>()).first { return s }
        let s = IsleState()
        context.insert(s)
        return s
    }

    func allTasks() -> [TaskItem] { (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] }
    func allHabits() -> [Habit] { (try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.order)]))) ?? [] }
    func allLogs() -> [HabitLog] { (try? context.fetch(FetchDescriptor<HabitLog>())) ?? [] }
    func checkin(for day: Int) -> DayCheckin? {
        ((try? context.fetch(FetchDescriptor<DayCheckin>())) ?? []).first { $0.dayKey == day }
    }

    func save() { try? context.save() }

    func earn(_ n: Int) {
        let s = isle()
        s.shells = max(0, s.shells + n)
        if n > 0 { s.growth += n } else { s.growth = max(0, s.growth + n) }
    }

    // MARK: tasks

    func toggle(_ task: TaskItem) {
        if task.isDone {
            task.doneAt = nil
            task.doneDayKey = nil
            earn(-Rewards.shells(for: task))
            Feedback.play(.undo)
        } else {
            task.doneAt = Date()
            task.doneDayKey = Day.today
            earn(Rewards.shells(for: task))
            Feedback.play(.tick)
            Feedback.play(.shell)
        }
        save()
    }

    @discardableResult
    func addTask(title: String, day: Int?, start: Int?, minutes: Int, priority: Bool = false) -> TaskItem {
        let t = TaskItem(title: title, dayKey: day, startMinutes: start, minutes: minutes)
        t.priority = priority
        if start != nil { t.remindBefore = 10 }
        context.insert(t)
        save()
        return t
    }

    func delete(_ task: TaskItem) {
        context.delete(task)
        save()
    }

    // MARK: habits

    func log(for habit: Habit, day: Int, logs: [HabitLog]) -> HabitLog? {
        logs.first { $0.habitID == habit.id && $0.dayKey == day }
    }

    func toggle(_ habit: Habit, day: Int = Day.today, lowBattery: Bool) {
        let logs = allLogs()
        if let existing = log(for: habit, day: day, logs: logs) {
            earn(-Rewards.shells(forHabitOnLowBattery: existing.kind == .lowBattery))
            context.delete(existing)
            Feedback.play(.undo)
        } else {
            let useLow = lowBattery && !habit.lowBatteryVersion.isEmpty
            context.insert(HabitLog(habitID: habit.id, dayKey: day, kind: useLow ? .lowBattery : .done, minuteOfDay: Day.minuteOfDay))
            earn(Rewards.shells(forHabitOnLowBattery: lowBattery))
            Feedback.play(.tick)
            Feedback.play(.shell)
        }
        save()
    }

    @discardableResult
    func addHabit(name: String, colorIndex: Int, target: Int, daysMask: Int = 127, time: Int? = nil, minutes: Int = 15) -> Habit {
        let order = (allHabits().map { $0.order }.max() ?? 0) + 1
        let h = Habit(name: name, colorIndex: colorIndex, targetPerWeek: target, daysMask: daysMask, timeMinutes: time, minutes: minutes)
        h.order = order
        context.insert(h)
        save()
        return h
    }

    func delete(_ habit: Habit) {
        for l in allLogs() where l.habitID == habit.id { context.delete(l) }
        context.delete(habit)
        save()
    }

    // MARK: day rules

    /// Unfinished tasks from earlier days that are still sitting on those days.
    func overdue() -> [TaskItem] {
        let today = Day.today
        return allTasks().filter { t in
            guard let d = t.dayKey else { return false }
            return d < today && !t.isDone
        }
    }

    /// Applies a morning check-in: rest day moves every task, low battery moves the big ones.
    func applyCheckin(battery: Int, moods: [String]) -> String {
        let today = Day.today
        if let old = checkin(for: today) { context.delete(old) }
        context.insert(DayCheckin(dayKey: today, battery: battery, moods: moods))
        var moved = 0
        if battery <= 1 {
            let week = Day.week(Day.weekStart(today)).filter { $0 > today }
            let targets = week.isEmpty ? [Day.add(today, days: 1), Day.add(today, days: 2)] : week
            let tasks = allTasks()
            let todays = tasks.filter { $0.dayKey == today && !$0.isDone && (battery == 0 || $0.isBig) }
            var loads: [Int: Int] = [:]
            for d in targets { loads[d] = tasks.filter { $0.dayKey == d }.reduce(0) { $0 + $1.minutes } }
            let s = settings()
            let plan = Planner.autoPlan(tasks: todays, days: targets, loads: loads, capacity: { s.capacity(forWeekday: Day.weekday($0)) })
            for (task, day) in plan { task.dayKey = day; task.startMinutes = nil; moved += 1 }
        }
        save()
        switch battery {
        case 0: return moved > 0 ? "Rest day: moved \(moved) task\(moved == 1 ? "" : "s") to later this week." : "Rest day. Just the easy habits today."
        case 1: return moved > 0 ? "Low battery: moved \(moved) big task\(moved == 1 ? "" : "s") later this week." : "Low battery mode is on."
        default: return "Plan stays as it is."
        }
    }

    func resetEverything() {
        for t in allTasks() { context.delete(t) }
        for h in allHabits() { context.delete(h) }
        for l in allLogs() { context.delete(l) }
        for c in (try? context.fetch(FetchDescriptor<DayCheckin>())) ?? [] { context.delete(c) }
        for j in (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? [] { context.delete(j) }
        for f in (try? context.fetch(FetchDescriptor<FreezeDay>())) ?? [] { context.delete(f) }
        for i in (try? context.fetch(FetchDescriptor<IsleState>())) ?? [] { context.delete(i) }
        for s in (try? context.fetch(FetchDescriptor<AppSettings>())) ?? [] { context.delete(s) }
        for l in (try? context.fetch(FetchDescriptor<NoteList>())) ?? [] { context.delete(l) }
        for e in (try? context.fetch(FetchDescriptor<ListEntry>())) ?? [] { context.delete(e) }
        for r in (try? context.fetch(FetchDescriptor<Routine>())) ?? [] { context.delete(r) }
        save()
    }
}

/// Habit maths shared by Today, Habits and the Isle.
enum HabitStats {
    static func doneDays(_ habit: Habit, logs: [HabitLog]) -> Set<Int> {
        Set(logs.filter { $0.habitID == habit.id }.map { $0.dayKey })
    }

    static func countInWeek(_ habit: Habit, weekStart: Int, logs: [HabitLog]) -> Int {
        let days = Set(Day.week(weekStart))
        return logs.filter { $0.habitID == habit.id && days.contains($0.dayKey) }.count
    }

    /// Weeks in a row (ending with last week, plus this week if already on target) that hit the target.
    static func weekStreak(_ habit: Habit, logs: [HabitLog], frozen: Set<Int>) -> Int {
        let thisWeek = Day.weekStart(Day.today)
        var streak = 0
        if countInWeek(habit, weekStart: thisWeek, logs: logs) >= habit.targetPerWeek { streak += 1 }
        var w = Day.add(thisWeek, days: -7)
        let created = Day.key(habit.createdAt)
        while w >= Day.weekStart(created) {
            let frozenCount = Day.week(w).filter { frozen.contains($0) }.count
            let need = max(0, habit.targetPerWeek - frozenCount)
            if countInWeek(habit, weekStart: w, logs: logs) >= need { streak += 1 } else { break }
            w = Day.add(w, days: -7)
            if streak > 520 { break }
        }
        return streak
    }

    static func usualTime(_ habit: Habit, logs: [HabitLog]) -> Int? {
        let mins = logs.filter { $0.habitID == habit.id && $0.minuteOfDay > 0 }.map { $0.minuteOfDay }
        guard mins.count >= 3 else { return habit.timeMinutes }
        let sorted = mins.sorted()
        return sorted[sorted.count / 2]
    }

    static func plantStage(_ habit: Habit, logs: [HabitLog]) -> Int {
        let n = logs.filter { $0.habitID == habit.id }.count
        return min(6, 1 + n / 6)
    }

    static func insight(_ habit: Habit, logs: [HabitLog]) -> String {
        let mins = logs.filter { $0.habitID == habit.id }.map { $0.minuteOfDay }
        guard mins.count >= 5 else { return "Do it a few more times and Pip will spot your patterns." }
        let morning = mins.filter { $0 < 12 * 60 }.count
        let evening = mins.filter { $0 >= 17 * 60 }.count
        if morning > evening * 2 { return "You mostly do this in the morning. Mornings are where it sticks." }
        if evening > morning * 2 { return "You mostly do this in the evening. Keep a slot free after dinner." }
        return "You do this at all sorts of times. A fixed time could make it easier."
    }
}
