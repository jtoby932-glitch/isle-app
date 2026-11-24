import SwiftUI
import SwiftData

/// Sunday planning: tap an inbox task, then a day. Or let Pip place everything.
struct SundayPlanView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @Query private var settingsRows: [AppSettings]
    @Query private var isles: [IsleState]

    @State private var selected: TaskItem? = nil
    @State private var flash: Int? = nil
    @State private var placedNow: [UUID: Int] = [:]
    @State private var planning = false
    @State private var newTitle = ""

    /// On Sunday you plan next week; any other day, the rest of this week.
    private var weekStart: Int {
        let today = Day.today
        return Day.weekday(today) == 6 ? Day.add(today, days: 1) : Day.weekStart(today)
    }
    private var days: [Int] { Day.week(weekStart) }
    private var settings: AppSettings? { settingsRows.first }
    private func capacity(_ d: Int) -> Int { settings?.capacity(forWeekday: Day.weekday(d)) ?? 420 }

    private var inbox: [TaskItem] {
        tasks.filter { !$0.isDone && ($0.dayKey == nil || placedNow[$0.id] != nil) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        let evs = CalendarService.shared.events(for: days, enabled: settings?.calendarOn ?? false)
        let loads = Dictionary(uniqueKeysWithValues: days.map { ($0, Planner.load(day: $0, tasks: tasks, habits: habits, events: evs)) })
        let unplaced = inbox.filter { $0.dayKey == nil }
        let anyOver = days.contains { (loads[$0] ?? 0) > capacity($0) && $0 >= Day.today }
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .buttonStyle(IconButtonStyle()).accessibilityLabel("Close")
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Plan the week").font(.isle(.title2, .heavy)).foregroundStyle(T.ink)
                            Text(Day.weekRange(weekStart)).font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                        }
                        Spacer()
                        PipView(mood: unplaced.isEmpty && !anyOver ? .cheer : (selected == nil ? .happy : .normal),
                                size: 62, colorIndex: isles.first?.bodyColorIndex ?? 0, outfit: "beanie")
                    }

                    Text(message(unplaced: unplaced.count, anyOver: anyOver))
                        .font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                        .animation(.easeOut(duration: 0.2), value: selected?.id)

                    recap

                    HStack(spacing: 5) {
                        ForEach(days, id: \.self) { d in dayColumn(d, load: loads[d] ?? 0) }
                    }

                    HStack {
                        Text("Inbox").font(.isle(.title3, .heavy)).foregroundStyle(T.ink)
                        Spacer()
                        Text(unplaced.isEmpty ? "all placed" : "\(unplaced.count) left to place")
                            .font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                    }

                    HStack(spacing: 8) {
                        TextField("Add to the inbox", text: $newTitle)
                            .font(.isle(.subheadline, .heavy))
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(T.surface))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.outline, lineWidth: 2))
                            .submitLabel(.done)
                            .onSubmit(addInbox)
                        Button("Add", action: addInbox).buttonStyle(PillButtonStyle(height: 44))
                    }

                    if inbox.isEmpty {
                        EmptyHint(title: "Inbox is empty", message: "Add things above, or use Quick add without a day.")
                    }
                    ForEach(inbox) { t in inboxRow(t) }
                }
                .padding(16)
            }
            HStack(spacing: 8) {
                Button(planning ? "Planning…" : "Auto-plan with Pip") { autoPlan(loads: loads) }
                    .buttonStyle(ChunkyButtonStyle(fill: T.lilacStrong, textColor: T.ink, height: 52, shadow: false))
                    .disabled(planning || unplaced.isEmpty)
                Button("Done") { finish() }
                    .buttonStyle(ChunkyButtonStyle(fill: unplaced.isEmpty ? T.primary : T.line, height: 52, shadow: unplaced.isEmpty))
            }
            .padding(16)
            .background(T.bg)
        }
        .screenBackground()
    }

    private func message(unplaced: Int, anyOver: Bool) -> String {
        if planning { return "Placing things where there's room…" }
        if let s = selected { return "Now tap a day for “\(s.title)”. Days with room are dashed." }
        if unplaced == 0 && anyOver { return "All placed, but a day is over. Tap a placed task to move it." }
        if unplaced == 0 { return "All placed and every day has breathing room. Lovely week!" }
        return "Tap a task, then a day. Or let Pip plan it for you."
    }

    private var recap: some View {
        let lastStart = Day.add(weekStart, days: -7)
        let lastDays = Set(Day.week(lastStart))
        let lastDone = tasks.filter { t in t.doneDayKey.map { lastDays.contains($0) } ?? false }.count
        let rolled = tasks.filter { t in !t.isDone && (t.dayKey.map { $0 < Day.today } ?? false) }.count
        var hit = 0
        for h in habits where HabitStats.countInWeek(h, weekStart: lastStart, logs: logs) >= h.targetPerWeek { hit += 1 }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                IsleChip(text: "Last week: \(lastDone) done")
                if !habits.isEmpty { IsleChip(text: "\(hit) of \(habits.count) habits on target") }
                if rolled > 0 { IsleChip(text: "\(rolled) rolled over", fill: T.warnSoft) }
            }
        }
    }

    private func dayColumn(_ d: Int, load: Int) -> some View {
        let cap = capacity(d)
        let over = load > cap
        let wouldOver = selected.map { load + $0.minutes > cap } ?? false
        let past = d < Day.today
        let targeting = selected != nil && !past
        let count = placedNow.values.filter { $0 == d }.count
        return Button {
            guard let s = selected, !past else { return }
            place(s, on: d)
        } label: {
            VStack(spacing: 4) {
                Text(Day.shortName(d)).font(.isle(.caption, .heavy)).foregroundStyle(T.ink)
                GeometryReader { g in
                    ZStack(alignment: .bottom) {
                        Capsule().fill(T.line)
                        Capsule().fill(over ? T.warn : (flash == d ? T.good : T.ink))
                            .frame(height: g.size.height * min(1, Double(load) / Double(max(1, cap))))
                    }
                    .frame(width: 14)
                    .frame(maxWidth: .infinity)
                }
                Text(String(format: "%.1fh", Double(load) / 60)).font(.isle(.caption2, .heavy))
                    .foregroundStyle(over ? T.warnText : T.muted)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            .background(RoundedRectangle(cornerRadius: 14).fill(targeting ? (wouldOver ? T.warnSoft : T.primarySoft.opacity(0.6)) : (past ? T.surface2 : T.surface)))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(targeting ? T.outline : T.line, style: StrokeStyle(lineWidth: 2, dash: targeting && !wouldOver ? [5, 3] : [])))
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("+\(count)").font(.isle(.caption2, .heavy)).foregroundStyle(T.primaryInk)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Circle().fill(T.good))
                        .overlay(Circle().strokeBorder(T.outline, lineWidth: 2))
                        .offset(x: 4, y: -8)
                        .transition(.scale)
                }
            }
            .scaleEffect(flash == d ? 1.08 : 1)
            .opacity(past ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(past)
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: flash)
        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: load)
        .accessibilityLabel("\(Day.longName(d)), \(Fmt.duration(load)) planned" + (selected != nil ? ", place here" : ""))
    }

    private func inboxRow(_ t: TaskItem) -> some View {
        let on = selected?.id == t.id
        let placedDay = t.dayKey
        return Button {
            Feedback.play(on ? .tap : .lift)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { selected = on ? nil : t }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal").font(.system(size: 14, weight: .bold)).foregroundStyle(T.muted)
                RoundedRectangle(cornerRadius: 3).fill(t.priority ? T.primary : T.habit(1)).frame(width: 6, height: 28)
                Text(t.title).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink).lineLimit(1)
                Spacer()
                Text(Fmt.duration(t.minutes)).font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                if let d = placedDay {
                    IsleTag(text: Day.shortName(d), fill: T.goodSoft).transition(.scale)
                } else {
                    IsleTag(text: t.size.label)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(on ? T.primarySoft.opacity(0.35) : (placedDay != nil ? T.surface2 : T.surface)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(placedDay != nil && !on ? T.line : T.outline, lineWidth: 2))
            .offset(y: on ? -4 : 0)
            .rotationEffect(.degrees(on ? -1 : 0))
            .shadow(color: on ? T.outline : .clear, radius: 0, x: 0, y: on ? 5 : 0)
        }
        .buttonStyle(.plain)
    }

    private func place(_ t: TaskItem, on d: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            t.dayKey = d
            t.startMinutes = nil
            placedNow[t.id] = d
            selected = nil
            flash = d
        }
        Feedback.play(.place(Day.weekday(d)))
        try? context.save()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if flash == d { flash = nil }
        }
        if inbox.allSatisfy({ $0.dayKey != nil }) { Feedback.play(.celebrate, after: 0.42) }
    }

    private func autoPlan(loads: [Int: Int]) {
        let todo = inbox.filter { $0.dayKey == nil }
        guard !todo.isEmpty else { return }
        planning = true
        selected = nil
        Feedback.play(.whoosh)
        let plan = Planner.autoPlan(tasks: todo, days: days, loads: loads, capacity: { capacity($0) })
        for (i, item) in plan.enumerated() {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(380_000_000 * (i + 1)))
                place(item.0, on: item.1)
                if i == plan.count - 1 { planning = false }
            }
        }
        if plan.isEmpty { planning = false }
    }

    private func addInbox() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let p = QuickParser.parse(t)
        Store(context: context).addTask(title: p.name.isEmpty ? t : p.name, day: nil, start: nil, minutes: p.minutes ?? 30)
        Feedback.play(.chip(inbox.count + 1))
        newTitle = ""
    }

    private func finish() {
        let s = Store(context: context)
        let isle = s.isle()
        var weeks = isle.plannedWeeks
        if !weeks.contains(weekStart) {
            weeks.insert(weekStart)
            isle.plannedWeeks = weeks
            s.earn(Rewards.planning)
            app.showToast("Week planned! +\(Rewards.planning) shells")
        }
        s.save()
        IsleNotifications.reschedule(tasks: tasks, habits: habits, settings: s.settings(), pipName: isle.pipName)
        Feedback.play(.celebrate)
        dismiss()
    }
}
