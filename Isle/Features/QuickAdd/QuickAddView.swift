import SwiftUI
import SwiftData

/// Add a task or habit fast: type it, or just tap chips for day, time and length.
/// Return adds it and keeps the sheet open for the next one.
struct QuickAddView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var settingsRows: [AppSettings]

    @State private var text = ""
    @State private var typeOverride: Int? = nil   // 0 task, 1 habit
    @State private var keepClash = false
    @State private var priority = false
    @State private var when: When? = nil
    @State private var startPicked = false
    @State private var pickedStart: Int? = nil
    @State private var customTime = false
    @State private var pickedMinutes: Int? = nil
    @State private var added: [String] = []
    @State private var preset: QuickAddPreset? = nil
    @FocusState private var focused: Bool

    enum When: Equatable {
        case inbox
        case day(Int)
    }

    private let examples = ["read daily 8:30am 15m", "dentist fri 2pm 45m", "finish draft wed 2h", "walk weekends 30m"]
    private let times = [9 * 60, 12 * 60, 15 * 60, 18 * 60, 20 * 60]
    private let lengths = [15, 30, 45, 60, 90, 120]

    private var parsed: ParsedInput { QuickParser.parse(text) }
    private var isHabit: Bool { typeOverride.map { $0 == 1 } ?? parsed.isHabit }

    // MARK: what will actually be saved

    private var day: Int? {
        switch when {
        case .inbox: return nil
        case .day(let d): return d
        case nil: return parsed.dayKey ?? preset?.day ?? Day.today
        }
    }

    private var start: Int? {
        startPicked ? pickedStart : (parsed.startMinutes ?? preset?.start)
    }

    private var minutes: Int { pickedMinutes ?? parsed.minutes ?? (isHabit ? 15 : 30) }

    private var recents: [TaskItem] {
        var seen = Set<String>()
        var out: [TaskItem] = []
        for t in tasks {
            let key = t.title.lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(t)
            if out.count == 10 { break }
        }
        return out
    }

    private var clashDay: Int? {
        guard !keepClash, !isHabit, let d = day else { return nil }
        let s = settingsRows.first
        let cap = s?.capacity(forWeekday: Day.weekday(d)) ?? 420
        let load = Planner.load(day: d, tasks: tasks, habits: habits, events: CalendarService.shared.events(for: d, enabled: s?.calendarOn ?? false))
        return load + minutes > cap ? d : nil
    }

    private var suggestedDay: Int? {
        guard let clash = clashDay else { return nil }
        let s = settingsRows.first
        let week = Day.week(Day.weekStart(clash)).filter { $0 >= Day.today && $0 != clash }
        return week.min { a, b in
            Planner.load(day: a, tasks: tasks, habits: habits, events: []) - (s?.capacity(forWeekday: Day.weekday(a)) ?? 420)
                < Planner.load(day: b, tasks: tasks, habits: habits, events: []) - (s?.capacity(forWeekday: Day.weekday(b)) ?? 420)
        }
    }

    // MARK: body

    var body: some View {
        let p = parsed
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                SegmentedPicker(options: [(0, "Task"), (1, "Habit")], selection: Binding(
                    get: { isHabit ? 1 : 0 },
                    set: { typeOverride = $0 }
                ))
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Close")
            }

            TextField(isHabit ? "e.g. read 15m daily" : "What do you need to do?", text: $text)
                .font(.isle(.title3, .heavy))
                .foregroundStyle(T.ink)
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(T.outline).offset(y: 3)
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(T.surface)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(T.outline, lineWidth: 2.5))
                .focused($focused)
                .submitLabel(.next)
                .onSubmit { save(keepOpen: true) }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !added.isEmpty { addedList }
                    recentRow
                    if !isHabit { whenRow }
                    timeRow
                    lengthRow
                    if !isHabit {
                        ToggleSwitch(label: "One of this week's top 3", isOn: $priority)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                    }
                    if let clash = clashDay { clashCard(clash) }
                    if isHabit && !p.name.isEmpty {
                        Text(habitSummary(p)).font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.never)

            HStack(spacing: 8) {
                Button { save(keepOpen: true) } label: { Label("Add another", systemImage: "plus") }
                    .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 54))
                    .frame(maxWidth: 170)
                    .disabled(p.name.isEmpty)
                Button { save(keepOpen: false) } label: { Text(ctaTitle(p)) }
                    .buttonStyle(ChunkyButtonStyle(fill: p.name.isEmpty ? (added.isEmpty ? T.line : T.good) : T.primary, height: 54))
            }
        }
        .padding(16)
        .screenBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            preset = app.quickAddPreset
            app.quickAddPreset = nil
            if preset?.start != nil { startPicked = false }
            focused = true
        }
        .onChange(of: p.chips.count) { old, new in
            if new > old { Feedback.play(.chip(new - 1)) }
        }
        .onChange(of: clashDay) { old, new in
            if old == nil && new != nil { Feedback.play(.hmm, after: 0.12) }
        }
    }

    // MARK: rows

    private var addedList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(added.enumerated()), id: \.offset) { _, title in
                Label(title, systemImage: "checkmark.circle.fill")
                    .font(.isle(.caption, .heavy))
                    .foregroundStyle(T.good)
                    .lineLimit(1)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var recentRow: some View {
        let list = recents
        VStack(alignment: .leading, spacing: 6) {
            Text(list.isEmpty ? "Try" : "Again?").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if list.isEmpty {
                        ForEach(examples, id: \.self) { e in
                            dashedChip(e) {
                                Feedback.play(.chip(2))
                                typeOverride = nil
                                text = e
                            }
                        }
                    } else {
                        ForEach(list) { t in
                            dashedChip("\(t.title) · \(Fmt.duration(t.minutes))") {
                                Feedback.play(.chip(2))
                                typeOverride = 0
                                text = t.title
                                pickedMinutes = t.minutes
                            }
                        }
                    }
                }
            }
        }
    }

    private var whenRow: some View {
        let today = Day.today
        return chipRow("When") {
            choice("Today", selected: day == today) { when = .day(today) }
            choice("Tomorrow", selected: day == Day.add(today, days: 1)) { when = .day(Day.add(today, days: 1)) }
            ForEach(2..<7, id: \.self) { offset in
                let d = Day.add(today, days: offset)
                choice("\(Day.shortName(d)) \(Day.dayNumber(d))", selected: day == d) { when = .day(d) }
            }
            choice("Inbox", selected: day == nil) { when = .inbox }
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            chipRow("Time") {
                choice("Any time", selected: start == nil) { startPicked = true; pickedStart = nil; customTime = false }
                if let s = start, !times.contains(s) {
                    choice(Fmt.clock(s), selected: true) {}
                }
                ForEach(times, id: \.self) { t in
                    choice(Fmt.clock(t), selected: start == t) { startPicked = true; pickedStart = t; customTime = false }
                }
                choice("Other…", selected: customTime) {
                    customTime.toggle()
                    if customTime {
                        startPicked = true
                        pickedStart = start ?? (Day.minuteOfDay / 15 + 1) * 15
                    }
                }
            }
            if customTime {
                DatePicker("Start time", selection: Binding(
                    get: { Day.dateAt(Day.today, minutes: pickedStart ?? 9 * 60) },
                    set: { d in
                        let c = Day.calendar.dateComponents([.hour, .minute], from: d)
                        startPicked = true
                        pickedStart = (c.hour ?? 9) * 60 + (c.minute ?? 0)
                    }
                ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 120)
                .clipped()
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
    }

    private var lengthRow: some View {
        chipRow("How long") {
            ForEach(lengths, id: \.self) { m in
                choice(Fmt.duration(m), selected: minutes == m) { pickedMinutes = m }
            }
        }
    }

    private func clashCard(_ clash: Int) -> some View {
        HStack(alignment: .top, spacing: 6) {
            PipView(mood: .normal, size: 44)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Day.longName(clash)) is already full.").font(.isle(.subheadline, .heavy))
                    + Text(suggestedDay.map { " \(Day.longName($0)) has room. Swap?" } ?? "").font(.isle(.subheadline, .semibold))
                HStack(spacing: 6) {
                    if let alt = suggestedDay {
                        Button("Use \(Day.shortName(alt))") {
                            Feedback.play(.place(Day.weekday(alt)))
                            when = .day(alt)
                        }
                        .buttonStyle(PillButtonStyle(fill: T.primary, textColor: T.primaryInk, height: 36))
                    }
                    Button("Keep it") { Feedback.play(.tap); keepClash = true }
                        .buttonStyle(PillButtonStyle(height: 36))
                }
            }
            .foregroundStyle(T.ink)
        }
        .card(fill: T.warnSoft)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    // MARK: chip helpers

    private func chipRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { content() }.padding(.vertical, 1)
            }
        }
    }

    private func choice(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.play(.chip(label.count % 10))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            Text(label)
                .font(.isle(.subheadline, .heavy))
                .foregroundStyle(selected ? T.primaryInk : T.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(selected ? T.primary : T.surface))
                .overlay(Capsule().strokeBorder(T.outline, lineWidth: selected ? 2 : 1.5))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dashedChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.isle(.caption, .heavy))
            .foregroundStyle(T.ink)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .overlay(Capsule().strokeBorder(T.muted.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    private func habitSummary(_ p: ParsedInput) -> String {
        let n = p.weekdays.isEmpty ? 7 : p.weekdays.count
        var s = n == 7 ? "Every day" : "\(n) days a week"
        if let st = start { s += " at \(Fmt.clock(st))" }
        return s + " · \(Fmt.duration(minutes))"
    }

    private func ctaTitle(_ p: ParsedInput) -> String {
        if p.name.isEmpty { return added.isEmpty ? "Type something" : "Done" }
        if isHabit { return "Plant habit" }
        guard let d = day else { return "Add to Inbox" }
        return "Add to \(Day.relative(d))"
    }

    // MARK: save

    private func save(keepOpen: Bool) {
        let p = parsed
        guard !p.name.isEmpty else {
            if !added.isEmpty && !keepOpen { dismiss(); return }
            Feedback.play(.hmm)
            return
        }
        let store = Store(context: context)
        if isHabit {
            var mask = 0
            let days = p.weekdays.isEmpty ? Array(0...6) : p.weekdays
            for d in days { mask |= (1 << d) }
            store.addHabit(name: p.name, colorIndex: p.colorIndex == 4 ? habits.count % 8 : p.colorIndex,
                           target: p.target ?? days.count, daysMask: mask, time: start, minutes: minutes)
            Feedback.play(.bloom(habits.count))
            if !keepOpen { app.showToast("Planted \(p.name). Pip will water it with you.") }
        } else {
            let d = day
            let t = store.addTask(title: p.name, day: d, start: start, minutes: minutes, priority: priority)
            if let d { Feedback.play(.place(Day.weekday(d))) } else { Feedback.play(.slide) }
            if !keepOpen {
                app.showToast(d == nil ? "Added to the Inbox." : "Added to \(Day.relative(d!)).") {
                    Store(context: context).delete(t)
                }
            }
        }
        guard keepOpen else { dismiss(); return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            added.append(p.name)
            text = ""
            priority = false
            keepClash = false
            typeOverride = nil
            startPicked = false
            pickedStart = nil
            customTime = false
            pickedMinutes = nil
            preset = preset.map { QuickAddPreset(day: $0.day, start: nil) }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            focused = true
        }
    }
}
