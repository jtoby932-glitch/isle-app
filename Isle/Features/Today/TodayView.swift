import SwiftUI
import SwiftData

/// One line on a day: a task, a habit or a calendar event.
struct IsleDayRow: Identifiable {
    enum Kind {
        case task(TaskItem)
        case habit(Habit)
        case event(CalEvent)
    }

    let id: String
    let kind: Kind
    let start: Int?
    let minutes: Int
    let title: String
    let sub: String
    let color: Color
    let done: Bool

    var isEvent: Bool { if case .event = kind { return true } else { return false } }
}

enum DayRows {
    @MainActor
    static func build(day: Int, tasks: [TaskItem], habits: [Habit], logs: [HabitLog], events: [CalEvent], lowBattery: Bool) -> [IsleDayRow] {
        var rows: [IsleDayRow] = []
        let wd = Day.weekday(day)
        for t in tasks where t.dayKey == day {
            var bits: [String] = []
            bits.append(t.priority ? "Priority" : "Task")
            bits.append(Fmt.duration(t.minutes))
            let steps = t.steps
            if !steps.isEmpty { bits.append("\(steps.filter { $0.done }.count)/\(steps.count) steps") }
            if let s = t.startMinutes { bits.append("until \(Fmt.clock(s + t.minutes))") }
            rows.append(IsleDayRow(id: "t-\(t.id)", kind: .task(t), start: t.startMinutes, minutes: t.minutes,
                               title: t.title, sub: bits.joined(separator: " · "),
                               color: t.priority ? T.primary : T.habit(4), done: t.isDone))
        }
        let weekStart = Day.weekStart(day)
        for h in habits where !h.paused && h.allowed(onWeekday: wd) {
            let doneToday = logs.contains { $0.habitID == h.id && $0.dayKey == day }
            let weekCount = HabitStats.countInWeek(h, weekStart: weekStart, logs: logs)
            // a weekly-target habit stops showing once the week's target is met (unless done today)
            if !h.isDaily && weekCount >= h.targetPerWeek && !doneToday { continue }
            let useLow = lowBattery && !h.lowBatteryVersion.isEmpty
            let title = useLow ? h.lowBatteryVersion : h.name
            var sub = "Habit · \(Fmt.duration(h.minutes))"
            if !h.isDaily { sub += " · \(weekCount) of \(h.targetPerWeek) this week" }
            if let chain = h.chainAfterID, let first = habits.first(where: { $0.id == chain }) { sub += " · after \(first.name.lowercased())" }
            if useLow { sub = "Low-battery version · double shells" }
            rows.append(IsleDayRow(id: "h-\(h.id)", kind: .habit(h), start: h.timeMinutes, minutes: h.minutes,
                               title: title, sub: sub, color: T.habit(h.colorIndex), done: doneToday))
        }
        for e in events {
            let sub = e.allDay ? "Calendar · all day" : "Calendar · \(Fmt.duration(e.minutes))"
            rows.append(IsleDayRow(id: "e-\(e.id)", kind: .event(e), start: e.allDay ? nil : e.startMinutes, minutes: e.minutes,
                               title: e.title, sub: sub, color: T.muted.opacity(0.6), done: false))
        }
        return rows.sorted { a, b in
            switch (a.start, b.start) {
            case let (x?, y?): return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.title < b.title
            }
        }
    }
}

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @Query private var checkins: [DayCheckin]
    @Query private var isles: [IsleState]
    @Query private var settingsRows: [AppSettings]

    @State private var tab = 0
    @State private var floating: [String: Int] = [:]
    @State private var rolloverDismissed = false

    private var store: Store { Store(context: context) }
    private var today: Int { Day.today }
    private var settings: AppSettings? { settingsRows.first }
    private var isle: IsleState? { isles.first }
    private var lowBattery: Bool { (checkins.first { $0.dayKey == today }?.battery ?? 2) <= 1 }

    private var events: [CalEvent] {
        _ = CalendarService.shared.revision
        return CalendarService.shared.events(for: today, enabled: settings?.calendarOn ?? false)
    }

    private var rows: [IsleDayRow] {
        DayRows.build(day: today, tasks: tasks, habits: habits, logs: logs, events: events, lowBattery: lowBattery)
    }

    var body: some View {
        let all = rows
        let checkable = all.filter { !$0.isEvent }
        let doneCount = checkable.filter { $0.done }.count
        let allDone = !checkable.isEmpty && doneCount == checkable.count
        ScrollView {
            VStack(spacing: 12) {
                header(all)
                if showRollover { rolloverBanner }
                if showCheckinPrompt { checkinPrompt }
                pipStrip(checkable: checkable, doneCount: doneCount, allDone: allDone)
                if checkable.isEmpty && events.isEmpty {
                    StarterSeedsView()
                } else {
                    SegmentedPicker(options: [(0, "Timeline"), (1, "List"), (2, "Anytime")], selection: $tab)
                    content(all)
                }
                if allDone { dayGrownBanner }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: header

    private func header(_ all: [IsleDayRow]) -> some View {
        let planned = all.filter { $0.start != nil || !$0.isEvent }.reduce(0) { $0 + $1.minutes }
        let cap = settings?.capacity(forWeekday: Day.weekday(today)) ?? 420
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Day.title(today)).font(.isle(.largeTitle)).foregroundStyle(T.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("\(Fmt.duration(planned)) planned · \(Fmt.duration(max(0, cap - planned))) free")
                    .font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
            }
            Spacer()
            SwitchToPrimeButton()
            Button { app.showShop = true } label: { ShellBadge(count: isle?.shells ?? 0) }
                .buttonStyle(PressStyle())
                .accessibilityHint("Opens the Shell Shop")
            Button { app.showSearch = true } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Search")
            Button { app.showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Settings")
        }
    }

    // MARK: banners

    private var overdueTasks: [TaskItem] {
        tasks.filter { t in
            guard let d = t.dayKey else { return false }
            return d < today && !t.isDone
        }
    }

    private var showRollover: Bool {
        !rolloverDismissed && (settings?.rolloverAsk ?? true) && !overdueTasks.isEmpty && (settings?.lastRolloverKey ?? 0) != today
    }

    private var rolloverBanner: some View {
        let n = overdueTasks.count
        return VStack(alignment: .leading, spacing: 10) {
            (Text("\(n) task\(n == 1 ? "" : "s") didn't get done. ").fontWeight(.heavy) + Text("Where should \(n == 1 ? "it" : "they") go?"))
                .font(.isle(.subheadline, .semibold))
                .foregroundStyle(T.ink)
            HStack(spacing: 8) {
                Button("Do today") { rollover(toToday: true) }
                    .buttonStyle(ChunkyButtonStyle(height: 44, shadow: false))
                Button("Later this week") { rollover(toToday: false) }
                    .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 44, shadow: false))
            }
        }
        .card(fill: Color.dynamic(0xF3E1D6, 0x3A2A33))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func rollover(toToday: Bool) {
        let items = overdueTasks
        if toToday {
            for t in items { t.dayKey = today; t.startMinutes = nil }
            Feedback.play(.slide)
        } else {
            let week = Day.week(Day.weekStart(today)).filter { $0 > today }
            let targets = week.isEmpty ? [Day.add(today, days: 1), Day.add(today, days: 2), Day.add(today, days: 3)] : week
            var loads: [Int: Int] = [:]
            for d in targets { loads[d] = tasks.filter { $0.dayKey == d }.reduce(0) { $0 + $1.minutes } }
            let s = settings
            for (t, d) in Planner.autoPlan(tasks: items, days: targets, loads: loads, capacity: { s?.capacity(forWeekday: Day.weekday($0)) ?? 420 }) {
                t.dayKey = d
                t.startMinutes = nil
            }
            Feedback.play(.whoosh)
        }
        settings?.lastRolloverKey = today
        store.save()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { rolloverDismissed = true }
    }

    private var showCheckinPrompt: Bool {
        (settings?.checkinOn ?? true) && !checkins.contains { $0.dayKey == today } && Day.minuteOfDay < 14 * 60
    }

    private var checkinPrompt: some View {
        Button { app.showCheckin = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "battery.50")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(T.primarySoft))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.outline, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text("How's your battery?").font(.isle(.headline))
                    Text("Ten seconds, and Pip shapes today around it.").font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(T.ink)
            .card()
        }
        .buttonStyle(PressStyle())
    }

    private func pipStrip(checkable: [IsleDayRow], doneCount: Int, allDone: Bool) -> some View {
        let next = checkable.first { !$0.done }
        let name = isle?.pipName ?? "Pip"
        let message: String
        if checkable.isEmpty {
            message = "\(name) is ready. Plant a few seeds below."
        } else if allDone {
            message = "All done. Your isle grew today!"
        } else if app.pipCheer {
            message = ["Nice one!", "Watered!", "Look at you go!"][doneCount % 3] + (next.map { " Next: \($0.title.lowercased())." } ?? "")
        } else if let n = next {
            message = "Next up: \(n.title.lowercased())" + (n.start.map { " at \(Fmt.clock($0))." } ?? ".")
        } else {
            message = "All clear!"
        }
        let mood: PipMood = (app.pipCheer || allDone) ? .cheer : (lowBattery || Day.minuteOfDay > 21 * 60 ? .sleepy : .happy)
        return HStack(spacing: 6) {
            PipView(mood: mood, size: 60, colorIndex: isle?.bodyColorIndex ?? 0, outfit: isle?.outfit ?? "none")
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink).lineLimit(2)
                    .animation(.easeOut(duration: 0.2), value: message)
                if !checkable.isEmpty {
                    HStack(spacing: 8) {
                        IsleProgressBar(value: Double(doneCount) / Double(max(1, checkable.count)))
                        Text("\(doneCount) of \(checkable.count)").font(.isle(.caption, .heavy)).foregroundStyle(T.muted).monospacedDigit()
                    }
                }
            }
        }
        .padding(.leading, 2)
        .card(padding: 8)
    }

    private var dayGrownBanner: some View {
        Button { app.showDayComplete = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day grown!").font(.isle(.title3, .heavy))
                    Text("See what bloomed on your isle").font(.isle(.subheadline))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .black))
            }
            .foregroundStyle(T.primaryInk)
            .card(fill: T.good, shadow: true)
        }
        .buttonStyle(PressStyle())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: content

    @ViewBuilder
    private func content(_ all: [IsleDayRow]) -> some View {
        switch tab {
        case 0: timeline(all)
        case 1:
            let items = all.filter { !$0.isEvent }
            let ordered = items.filter { !$0.done } + items.filter { $0.done }
            rowsList(ordered, showTime: false)
        default:
            rowsList(all.filter { $0.start == nil && !$0.isEvent }, showTime: false, emptyText: "Nothing without a time today.")
        }
    }

    @ViewBuilder
    private func rowsList(_ list: [IsleDayRow], showTime: Bool, emptyText: String = "Nothing here.") -> some View {
        if list.isEmpty {
            EmptyHint(title: "All clear", message: emptyText)
        } else {
            VStack(spacing: 6) {
                ForEach(list) { r in rowView(r, showTime: showTime) }
            }
        }
    }

    private func timeline(_ all: [IsleDayRow]) -> some View {
        let timed = all.filter { $0.start != nil }
        let untimed = all.filter { $0.start == nil }
        let now = Day.minuteOfDay
        let nowIndex = timed.firstIndex { ($0.start ?? 0) > now } ?? timed.count
        let gap = gapSuggestion(timed: timed)
        return VStack(spacing: 6) {
            ForEach(Array(timed.enumerated()), id: \.element.id) { i, r in
                if i == nowIndex { nowLine(now) }
                if let g = gap, g.index == i { gapRow(g) }
                rowView(r, showTime: true)
            }
            if nowIndex == timed.count { nowLine(now) }
            if let g = gap, g.index >= timed.count { gapRow(g) }
            if !untimed.isEmpty {
                SectionLabel(text: "Anytime today").padding(.top, 6)
                ForEach(untimed) { r in rowView(r, showTime: false) }
            }
        }
    }

    private func nowLine(_ minutes: Int) -> some View {
        HStack(spacing: 8) {
            Text(Fmt.clock(minutes)).font(.isle(.caption, .heavy)).foregroundStyle(T.now).frame(width: 42, alignment: .trailing)
            NowDot()
            Rectangle().fill(T.now).frame(height: 2)
        }
        .frame(height: 18)
        .accessibilityLabel("Now, \(Fmt.clock(minutes))")
    }

    struct Gap {
        var index: Int
        var start: Int
        var length: Int
        var task: TaskItem
    }

    private func gapSuggestion(timed: [IsleDayRow]) -> Gap? {
        let blocks = timed.filter { !$0.done }.compactMap { r -> (start: Int, minutes: Int)? in
            guard let s = r.start else { return nil }
            return (s, r.minutes)
        }
        guard let free = Planner.freeGap(day: today, timed: blocks, from: max(Day.minuteOfDay, 7 * 60)) else { return nil }
        let candidates = tasks.filter { !$0.isDone && $0.startMinutes == nil && ($0.dayKey == today || $0.dayKey == nil) && $0.minutes <= free.length }
        guard let pick = candidates.sorted(by: { ($0.dayKey == nil ? 1 : 0, $0.minutes) < ($1.dayKey == nil ? 1 : 0, $1.minutes) }).first else { return nil }
        let index = timed.firstIndex { ($0.start ?? 0) > free.start } ?? timed.count
        return Gap(index: index, start: free.start, length: free.length, task: pick)
    }

    private func gapRow(_ g: Gap) -> some View {
        HStack(spacing: 8) {
            Text(Fmt.clock(g.start)).font(.isle(.caption, .heavy)).foregroundStyle(T.muted).frame(width: 42, alignment: .trailing)
            HStack {
                Text("\(Fmt.duration(g.length)) free. \(g.task.title) fits (\(Fmt.duration(g.task.minutes))).")
                    .font(.isle(.footnote, .bold)).foregroundStyle(T.muted)
                Spacer(minLength: 6)
                Button("Slot it") {
                    Feedback.play(.slide)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        g.task.dayKey = today
                        g.task.startMinutes = g.start
                        store.save()
                    }
                }
                .buttonStyle(PillButtonStyle(fill: T.primarySoft, height: 34))
            }
            .padding(.leading, 10).padding(.trailing, 6)
            .frame(minHeight: 46)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.muted.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
        }
    }

    // MARK: rows

    private func rowView(_ r: IsleDayRow, showTime: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if showTime {
                Text(r.start.map { Fmt.clock($0) } ?? "")
                    .font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                    .frame(width: 42, alignment: .trailing)
            }
            DayRowCard(row: r,
                       floating: floating[r.id],
                       onOpen: { open(r) },
                       onToggle: { toggle(r) },
                       onFocus: { focus(r) })
        }
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }

    private func open(_ r: IsleDayRow) {
        switch r.kind {
        case .task(let t): Feedback.play(.tap); app.editingTask = t
        case .habit(let h): Feedback.play(.tap); app.openHabit = h
        case .event: break
        }
    }

    private func focus(_ r: IsleDayRow) {
        if case .task(let t) = r.kind {
            Feedback.play(.tap)
            app.focusTask = t
            app.showFocus = true
        }
    }

    private func toggle(_ r: IsleDayRow) {
        let becoming = !r.done
        var reward = 10
        switch r.kind {
        case .task(let t):
            reward = Rewards.shells(for: t)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.toggle(t) }
        case .habit(let h):
            reward = Rewards.shells(forHabitOnLowBattery: lowBattery)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.toggle(h, lowBattery: lowBattery) }
        case .event:
            return
        }
        guard becoming else { return }
        let token = (floating[r.id] ?? 0) + 1
        floating[r.id] = token
        app.cheer()
        if token % 3 == 0 || Int.random(in: 0..<3) == 0 { Feedback.play(.chirp, after: 0.26) }
        let remaining = rows.filter { !$0.isEvent && !$0.done }
        if remaining.isEmpty { Feedback.play(.celebrate, after: 0.38) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 950_000_000)
            if floating[r.id] == token { floating[r.id] = nil }
        }
        _ = reward
    }
}

struct NowDot: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle().fill(T.now).frame(width: 10, height: 10)
            .background(
                Circle().stroke(T.now.opacity(pulse ? 0 : 0.55), lineWidth: pulse ? 9 : 1)
                    .scaleEffect(pulse ? 1.8 : 1)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}

/// The card for one row: colour bar, title, detail, Focus button, tick.
struct DayRowCard: View {
    let row: IsleDayRow
    var floating: Int?
    var onOpen: () -> Void
    var onToggle: () -> Void
    var onFocus: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(row.color).frame(width: 6)
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title)
                        .font(.isle(.body, .heavy))
                        .foregroundStyle(row.done ? T.muted : T.ink)
                        .strikethrough(row.done, color: T.muted)
                        .lineLimit(2)
                    Text(row.sub).font(.isle(.caption, .bold)).foregroundStyle(T.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(row.isEvent)

            if case .task(let t) = row.kind, !row.done, t.minutes >= 45 {
                Button("Focus", action: onFocus)
                    .buttonStyle(PillButtonStyle(fill: T.lilacStrong, height: 32))
            }
            if !row.isEvent {
                Button(action: onToggle) {
                    CheckCircle(done: row.done)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.done ? "Undo \(row.title)" : "Complete \(row.title)")
                .overlay(alignment: .top) {
                    if let token = floating {
                        FloatingReward(text: "+\(row.sub.hasPrefix("Low-battery") ? 20 : rewardGuess)")
                            .id(token)
                            .offset(y: -14)
                    }
                }
            }
        }
        .padding(.trailing, row.isEvent ? 12 : 4)
        .frame(minHeight: 52)
        .background(row.isEvent ? T.surface2 : (row.done ? T.goodSoft.opacity(0.5) : T.surface))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(T.outline, style: StrokeStyle(lineWidth: 2, dash: row.isEvent ? [5, 4] : []))
        )
        .animation(.easeOut(duration: 0.25), value: row.done)
    }

    private var rewardGuess: Int {
        if case .task(let t) = row.kind { return Rewards.shells(for: t) }
        return 10
    }
}
