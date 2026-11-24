import SwiftUI
import SwiftData

// Moving tasks around, routines and lists. Kept beside Store so every write
// still goes through one place.
extension Store {

    // MARK: moving tasks

    /// Sends a task to another day (nil = Inbox). Keeps its time unless told to clear it.
    func move(_ task: TaskItem, to day: Int?, keepTime: Bool = true) {
        task.dayKey = day
        if !keepTime || day == nil { task.startMinutes = nil }
        save()
    }

    func setStart(_ task: TaskItem, _ start: Int?) {
        task.startMinutes = start.map { min(max(0, $0), 24 * 60 - 15) }
        if start != nil && task.remindBefore == nil { task.remindBefore = 10 }
        save()
    }

    @discardableResult
    func duplicate(_ task: TaskItem) -> TaskItem {
        let copy = TaskItem(title: task.title, dayKey: task.dayKey, startMinutes: nil, minutes: task.minutes)
        copy.priority = task.priority
        copy.steps = task.steps.map { TaskStep(title: $0.title) }
        context.insert(copy)
        save()
        return copy
    }

    // MARK: routines

    func allRoutines() -> [Routine] {
        (try? context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    /// Drops a routine's blocks onto a day as tasks. Returns them so the caller can undo.
    @discardableResult
    func apply(_ routine: Routine, to day: Int) -> [TaskItem] {
        var made: [TaskItem] = []
        for item in routine.items {
            let t = TaskItem(title: item.title, dayKey: day, startMinutes: item.start, minutes: item.minutes)
            if item.start != nil { t.remindBefore = 10 }
            context.insert(t)
            made.append(t)
        }
        routine.timesUsed += 1
        save()
        return made
    }

    /// Turns what's on a day into routine blocks (tasks and timed habits are left as they are).
    func routineItems(fromDay day: Int) -> [RoutineItem] {
        allTasks()
            .filter { $0.dayKey == day }
            .sorted { ($0.startMinutes ?? 99_999, $0.createdAt) < ($1.startMinutes ?? 99_999, $1.createdAt) }
            .map { RoutineItem(title: $0.title, start: $0.startMinutes, minutes: $0.minutes) }
    }

    @discardableResult
    func addRoutine(name: String, items: [RoutineItem]) -> Routine {
        let all = allRoutines()
        let r = Routine(name: name, colorIndex: all.count % 8, items: items, order: (all.map(\.order).max() ?? -1) + 1)
        context.insert(r)
        save()
        return r
    }

    // MARK: lists

    func entries(for list: NoteList) -> [ListEntry] {
        let id = list.id
        let d = FetchDescriptor<ListEntry>(predicate: #Predicate { $0.listID == id }, sortBy: [SortDescriptor(\.order)])
        return (try? context.fetch(d)) ?? []
    }

    @discardableResult
    func addList(title: String, checklist: Bool) -> NoteList {
        let all = (try? context.fetch(FetchDescriptor<NoteList>())) ?? []
        let l = NoteList(title: title, isChecklist: checklist, colorIndex: all.count % 8,
                         order: (all.map(\.order).max() ?? -1) + 1)
        context.insert(l)
        save()
        return l
    }

    @discardableResult
    func addEntry(_ text: String, to list: NoteList) -> ListEntry {
        let order = (entries(for: list).map(\.order).max() ?? -1) + 1
        let e = ListEntry(listID: list.id, text: text, order: order)
        context.insert(e)
        list.updatedAt = Date()
        save()
        return e
    }

    func delete(_ list: NoteList) {
        for e in entries(for: list) { context.delete(e) }
        context.delete(list)
        save()
    }
}

/// The long-press menu for a task anywhere in Isle: move it, re-time it, copy it, bin it.
struct TaskActionsMenu: View {
    let task: TaskItem
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context

    private var store: Store { Store(context: context) }

    var body: some View {
        let today = Day.today
        if task.dayKey != today {
            Button { send(to: today, label: "today") } label: { Label("Do today", systemImage: "sun.max") }
        }
        if task.dayKey != Day.add(today, days: 1) {
            Button { send(to: Day.add(today, days: 1), label: "tomorrow") } label: { Label("Tomorrow", systemImage: "sunrise") }
        }
        Menu {
            ForEach(2..<8, id: \.self) { offset in
                let d = Day.add(today, days: offset)
                Button(Day.longName(d) + " " + Day.dayMonth(d)) { send(to: d, label: Day.longName(d)) }
            }
            Button { send(to: nil, label: "the Inbox") } label: { Label("Inbox", systemImage: "tray") }
        } label: {
            Label("Move to…", systemImage: "calendar")
        }
        if let start = task.startMinutes {
            Button { shift(start, by: 60) } label: { Label("An hour later", systemImage: "clock.arrow.circlepath") }
            Button {
                Feedback.play(.slide)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { store.setStart(task, nil) }
            } label: { Label("Any time that day", systemImage: "clock.badge.xmark") }
        }
        Button {
            Feedback.play(.tap)
            store.duplicate(task)
            app.showToast("Copied \(task.title).")
        } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button(role: .destructive) {
            let snapshot = (task.title, task.dayKey, task.startMinutes, task.minutes, task.priority, task.steps)
            Feedback.play(.undo)
            withAnimation { store.delete(task) }
            app.showToast("Deleted \(snapshot.0).") {
                let s = Store(context: context)
                let t = s.addTask(title: snapshot.0, day: snapshot.1, start: snapshot.2, minutes: snapshot.3, priority: snapshot.4)
                t.steps = snapshot.5
                s.save()
            }
        } label: { Label("Delete", systemImage: "trash") }
    }

    private func send(to day: Int?, label: String) {
        let before = (task.dayKey, task.startMinutes)
        if let d = day { Feedback.play(.place(Day.weekday(d))) } else { Feedback.play(.slide) }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { store.move(task, to: day) }
        app.showToast("Moved to \(label).") {
            task.dayKey = before.0
            task.startMinutes = before.1
            Store(context: context).save()
        }
    }

    private func shift(_ start: Int, by minutes: Int) {
        Feedback.play(.slide)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { store.setStart(task, start + minutes) }
    }
}
