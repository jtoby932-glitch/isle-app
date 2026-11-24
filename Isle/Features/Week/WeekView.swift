import SwiftUI
import SwiftData

struct WeekView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @Query private var settingsRows: [AppSettings]

    @State private var weekOffset = 0
    @State private var open: Int? = Day.today
    @State private var lastFix: [(TaskItem, Int)] = []

    private var settings: AppSettings? { settingsRows.first }
    private var store: Store { Store(context: context) }
    private var weekStart: Int { Day.add(Day.weekStart(Day.today), days: weekOffset * 7) }
    private var days: [Int] { Day.week(weekStart) }

    private func capacity(_ d: Int) -> Int { settings?.capacity(forWeekday: Day.weekday(d)) ?? 420 }

    private var events: [CalEvent] {
        _ = CalendarService.shared.revision
        return CalendarService.shared.events(for: days, enabled: settings?.calendarOn ?? false)
    }

    var body: some View {
        let evs = events
        let loads: [Int: Int] = Dictionary(uniqueKeysWithValues: days.map { ($0, Planner.load(day: $0, tasks: tasks, habits: habits, events: evs)) })
        let stormy = days.filter { (loads[$0] ?? 0) > capacity($0) && $0 >= Day.today }
        let inboxCount = tasks.filter { $0.dayKey == nil && !$0.isDone }.count
        let priorities = tasks.filter { $0.priority && !$0.isDone && ($0.dayKey.map { days.contains($0) } ?? false) }
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week \(Day.weekNumber(weekStart))").font(.isle(.largeTitle)).foregroundStyle(T.ink)
                        Text("\(Day.weekRange(weekStart)) · \(Fmt.duration(loads.values.reduce(0, +))) planned")
                            .font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                    }
                    Spacer()
                    Button { Feedback.play(.tap); withAnimation { weekOffset -= 1 } } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Previous week")
                    Button { Feedback.play(.tap); withAnimation { weekOffset += 1 } } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Next week")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button("Inbox · \(inboxCount) unplanned") { app.showSunday = true }
                            .buttonStyle(PillButtonStyle(fill: T.primarySoft, height: 34))
                        if weekOffset != 0 {
                            Button("This week") { Feedback.play(.tap); withAnimation { weekOffset = 0 } }
                                .buttonStyle(PillButtonStyle(height: 34))
                        }
                        ForEach(priorities.prefix(3)) { p in
                            IsleChip(text: p.title, dot: T.primary)
                        }
                    }
                }

                VStack(spacing: 6) {
                    ForEach(days, id: \.self) { d in
                        dayRow(d, load: loads[d] ?? 0, events: evs.filter { $0.dayKey == d })
                    }
                }

                if let d = stormy.first {
                    stormCard(day: d, loads: loads)
                } else if !lastFix.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark").font(.system(size: 18, weight: .black)).foregroundStyle(T.good)
                        Text("Every day has breathing room now.").font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                        Spacer()
                        Button("Undo") { undoFix() }.buttonStyle(PillButtonStyle(height: 36))
                    }
                    .card(fill: T.goodSoft)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }

                Button {
                    Feedback.play(.lift)
                    app.showSunday = true
                } label: {
                    Label("Plan the week with Pip", systemImage: "sparkles")
                }
                .buttonStyle(ChunkyButtonStyle(fill: T.lilacStrong, textColor: T.ink, height: 50, shadow: false))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private func dayRow(_ d: Int, load: Int, events: [CalEvent]) -> some View {
        let cap = capacity(d)
        let over = load > cap
        let isToday = d == Day.today
        let isOpen = open == d
        let dayTasks = tasks.filter { $0.dayKey == d }
        let rows = DayRows.build(day: d, tasks: tasks, habits: habits, logs: logs, events: events, lowBattery: false)
        let taskCount = dayTasks.count
        let wd = Day.weekday(d)
        return VStack(spacing: 0) {
            Button {
                Feedback.play(isOpen ? .tap : .lift)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { open = isOpen ? nil : d }
            } label: {
                HStack(spacing: 10) {
                    VStack(spacing: 0) {
                        Text(Day.shortName(d)).font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                        Text("\(Day.dayNumber(d))").font(.isle(.title3, .heavy)).foregroundStyle(T.ink)
                    }
                    .frame(width: 40)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(taskCount) task\(taskCount == 1 ? "" : "s")" + (events.isEmpty ? "" : " · \(events.count) event\(events.count == 1 ? "" : "s")"))
                                .font(.isle(.caption, .heavy)).foregroundStyle(T.ink)
                            Spacer()
                            Text("\(Fmt.duration(load)) / \(Fmt.duration(cap))")
                                .font(.isle(.caption, .heavy)).foregroundStyle(over ? T.warnText : T.muted).monospacedDigit()
                        }
                        IsleProgressBar(value: Double(load) / Double(max(1, cap)), color: over ? T.warn : T.ink)
                        HStack(spacing: 4) {
                            ForEach(habits.filter { !$0.paused }.prefix(8)) { h in
                                let done = logs.contains { $0.habitID == h.id && $0.dayKey == d }
                                let allowed = h.allowed(onWeekday: wd)
                                Circle()
                                    .fill(done ? T.habit(h.colorIndex) : (allowed ? T.surface : T.line))
                                    .overlay(Circle().strokeBorder(done ? T.outline : T.habit(h.colorIndex), lineWidth: allowed || done ? 1.5 : 0))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(T.ink)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Day.longName(d)) \(Day.dayNumber(d)), \(Fmt.duration(load)) planned\(over ? ", overloaded" : "")")

            if isOpen {
                VStack(spacing: 6) {
                    if rows.isEmpty {
                        Text("Nothing planned.").font(.isle(.footnote, .bold)).foregroundStyle(T.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(rows.prefix(8)) { r in
                        Button {
                            if case .task(let t) = r.kind { Feedback.play(.tap); app.editingTask = t }
                            if case .habit(let h) = r.kind { Feedback.play(.tap); app.openHabit = h }
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(r.color).frame(width: 4, height: 18)
                                Text(r.title).font(.isle(.footnote, .heavy)).foregroundStyle(r.done ? T.muted : T.ink)
                                    .strikethrough(r.done)
                                Spacer()
                                Text(r.start.map { Fmt.clock($0) } ?? Fmt.duration(r.minutes))
                                    .font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.leading, 60).padding(.trailing, 12).padding(.bottom, 10)
            }
        }
        .background(over ? T.warnSoft : T.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isToday ? T.outline : (over ? T.warn : T.line), lineWidth: isToday ? 2.5 : 2))
    }

    private func stormCard(day: Int, loads: [Int: Int]) -> some View {
        let over = (loads[day] ?? 0) - capacity(day)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Day.longName(day)) is \(Fmt.duration(over)) over.").font(.isle(.subheadline, .heavy))
                Text("Pip can move the smallest tasks to lighter days.").font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
            }
            .foregroundStyle(T.ink)
            Spacer()
            Button("Fix it") { fix(day: day, loads: loads) }
                .buttonStyle(PillButtonStyle(fill: T.primary, textColor: T.primaryInk, height: 40))
        }
        .card(fill: T.warnSoft)
    }

    private func fix(day: Int, loads: [Int: Int]) {
        let moves = Planner.fix(day: day, week: days, tasks: tasks, loads: loads, capacity: { capacity($0) })
        guard !moves.isEmpty else {
            Feedback.play(.hmm)
            app.showToast("Nothing small enough to move. Try Edit on a big task.")
            return
        }
        Feedback.play(.whoosh)
        lastFix = moves.map { ($0.0, $0.0.dayKey ?? day) }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            for (t, d) in moves { t.dayKey = d }
            open = moves.first?.1
        }
        store.save()
        if let d = moves.first?.1 { Feedback.play(.place(Day.weekday(d)), after: 0.25) }
        Feedback.play(.tick, after: 0.5)
    }

    private func undoFix() {
        Feedback.play(.undo)
        withAnimation {
            for (t, d) in lastFix { t.dayKey = d }
            lastFix = []
        }
        store.save()
    }
}
