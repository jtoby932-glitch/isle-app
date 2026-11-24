import SwiftUI
import SwiftData

struct QuickAddView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var settingsRows: [AppSettings]

    @State private var text = ""
    @State private var typeOverride: Int? = nil   // 0 task, 1 habit
    @State private var keepClash = false
    @State private var lastChipCount = 0
    @State private var priority = false
    @FocusState private var focused: Bool

    private let examples = ["read daily 8:30am 15m", "dentist fri 2pm 45m", "finish draft wed 2h", "walk weekends 30m", "gym mon wed fri 7am 45m"]

    private var parsed: ParsedInput { QuickParser.parse(text) }
    private var isHabit: Bool { typeOverride.map { $0 == 1 } ?? parsed.isHabit }

    private var clashDay: Int? {
        guard !keepClash, !isHabit, let day = parsed.dayKey else { return nil }
        let s = settingsRows.first
        let cap = s?.capacity(forWeekday: Day.weekday(day)) ?? 420
        let load = Planner.load(day: day, tasks: tasks, habits: habits, events: CalendarService.shared.events(for: day, enabled: s?.calendarOn ?? false))
        return load + (parsed.minutes ?? 30) > cap ? day : nil
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

    var body: some View {
        let p = parsed
        let chips = chipList(p)
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                SegmentedPicker(options: [(0, "Task"), (1, "Habit")], selection: Binding(
                    get: { isHabit ? 1 : 0 },
                    set: { typeOverride = $0 }
                ))
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Just type it. Pip works out the rest.").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                TextField("e.g. read daily 8:30am 15m", text: $text)
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
                    .submitLabel(.done)
                    .onSubmit(save)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(examples, id: \.self) { e in
                        Button(e) {
                            Feedback.play(.chip(2))
                            typeOverride = nil
                            keepClash = false
                            text = e
                        }
                        .font(.isle(.caption, .heavy))
                        .foregroundStyle(T.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .overlay(Capsule().strokeBorder(T.muted.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(chips.isEmpty ? "Start typing and Pip will sort it" : "Pip understood")
                    .font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                IsleFlowLayout(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { i, c in
                        IsleChip(text: c, dot: i == 0 ? T.habit(p.colorIndex) : nil, fill: i == 0 ? T.primarySoft.opacity(0.5) : T.surface)
                            .transition(.scale(scale: 0.85).combined(with: .opacity).combined(with: .offset(y: 8)))
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.6), value: chips)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)

            if let clash = clashDay {
                HStack(alignment: .top, spacing: 6) {
                    PipView(mood: .normal, size: 48)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Day.longName(clash)) is already full.").font(.isle(.subheadline, .heavy))
                            + Text(suggestedDay.map { " \(Day.longName($0)) has room. Swap?" } ?? "").font(.isle(.subheadline, .semibold))
                        HStack(spacing: 6) {
                            if let alt = suggestedDay {
                                Button("Use \(Day.shortName(alt))") { useDay(alt) }
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

            if !isHabit {
                ToggleSwitch(label: "One of this week's top 3", isOn: $priority)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
            }

            Spacer(minLength: 0)

            Button(action: save) { Text(ctaTitle(p)) }
                .buttonStyle(ChunkyButtonStyle(fill: p.name.isEmpty ? T.line : T.primary))
                .disabled(p.name.isEmpty)
        }
        .padding(16)
        .screenBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
        .onChange(of: chips.count) { old, new in
            if new > old { Feedback.play(.chip(new - 1)) }
        }
        .onChange(of: clashDay) { old, new in
            if old == nil && new != nil { Feedback.play(.hmm, after: 0.12) }
        }
    }

    private func chipList(_ p: ParsedInput) -> [String] {
        var c = p.chips
        if !isHabit {
            c.removeAll { $0.hasSuffix("× a week") }
            if let d = p.dayKey { c.insert(Day.relative(d), at: min(1, c.count)) }
            else if p.weekdays.isEmpty && !p.name.isEmpty { c.insert("Inbox", at: min(1, c.count)) }
        } else if !p.isHabit && !p.name.isEmpty {
            c.append("Daily")
        }
        return c
    }

    private func ctaTitle(_ p: ParsedInput) -> String {
        if p.name.isEmpty { return "Type something first" }
        if isHabit {
            let n = p.weekdays.isEmpty ? 7 : p.weekdays.count
            return "Plant habit · \(n) seed\(n == 1 ? "" : "s")"
        }
        return p.dayKey == nil ? "Add to Inbox" : "Add to \(Day.relative(p.dayKey!))"
    }

    private func useDay(_ d: Int) {
        Feedback.play(.place(Day.weekday(d)))
        let name = Day.shortNames[Day.weekday(d)].lowercased()
        var t = text.replacingOccurrences(of: "\\b(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)[a-z]*\\b|\\btoday\\b|\\btomorrow\\b",
                                          with: name, options: [.regularExpression, .caseInsensitive])
        if t == text { t += " " + name }
        text = t
    }

    private func save() {
        let p = parsed
        guard !p.name.isEmpty else { Feedback.play(.hmm); return }
        let store = Store(context: context)
        if isHabit {
            var mask = 0
            let days = p.weekdays.isEmpty ? Array(0...6) : p.weekdays
            for d in days { mask |= (1 << d) }
            let target = p.target ?? days.count
            store.addHabit(name: p.name, colorIndex: p.colorIndex == 4 ? habits.count % 8 : p.colorIndex,
                           target: target, daysMask: mask, time: p.startMinutes, minutes: p.minutes ?? 15)
            Feedback.play(.bloom(habits.count))
            app.showToast("Planted \(p.name). Pip will water it with you.")
        } else {
            let t = store.addTask(title: p.name, day: p.dayKey, start: p.startMinutes, minutes: p.minutes ?? 30, priority: priority)
            if let d = p.dayKey { Feedback.play(.place(Day.weekday(d))) } else { Feedback.play(.slide) }
            app.showToast(p.dayKey == nil ? "Added to the Inbox." : "Added to \(Day.relative(p.dayKey!)).") {
                Store(context: context).delete(t)
            }
        }
        dismiss()
    }
}
