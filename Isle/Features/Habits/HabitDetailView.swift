import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit
    @Query private var logs: [HabitLog]
    @Query private var frozenDays: [FreezeDay]

    @State private var selected: Int? = nil
    @State private var editing = false
    @State private var treeGrown = false
    @State private var confirmDelete = false

    var body: some View {
        let mine = logs.filter { $0.habitID == habit.id }
        let frozen = Set(frozenDays.map { $0.dayKey })
        let weekStart = Day.weekStart(Day.today)
        let count = HabitStats.countInWeek(habit, weekStart: weekStart, logs: mine)
        let streak = HabitStats.weekStreak(habit, logs: mine, frozen: frozen)
        let usual = HabitStats.usualTime(habit, logs: mine)
        let stage = HabitStats.plantStage(habit, logs: mine)
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Close")
                    RoundedRectangle(cornerRadius: 14).fill(T.habit(habit.colorIndex))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(habit.name).font(.isle(.title2, .heavy)).foregroundStyle(T.ink).lineLimit(1)
                        Text(subtitle).font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                    }
                    Spacer()
                    Button("Edit") { Feedback.play(.tap); editing = true }.buttonStyle(PillButtonStyle(height: 40))
                }

                HStack(spacing: 8) {
                    stat("\(count)/\(habit.targetPerWeek)", "this week")
                    stat("\(streak) wk\(streak == 1 ? "" : "s")", "on target")
                    stat(usual.map { Fmt.clock($0) } ?? "–", "usual time")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Last 12 weeks").font(.isle(.footnote, .heavy)).foregroundStyle(T.ink)
                        Spacer()
                        Text(selectedText(mine, frozen: frozen) ?? "\(mine.count) sessions")
                            .font(.isle(.footnote, .heavy))
                            .foregroundStyle(selected == nil ? T.muted : T.ink)
                            .lineLimit(1)
                            .animation(.easeOut(duration: 0.2), value: selected)
                    }
                    heatmap(mine, frozen: frozen)
                    HStack(spacing: 12) {
                        legend(T.habit(habit.colorIndex), "Done")
                        legend(T.habit(habit.colorIndex).opacity(0.4), "Low-battery")
                        legend(T.line, "Paused day")
                    }
                }
                .card()

                HStack(spacing: 10) {
                    ZStack(alignment: .bottom) {
                        Ellipse().fill(T.soil).frame(width: 46, height: 12)
                        PlantView(color: T.habit(habit.colorIndex), height: CGFloat(20 + stage * 7), head: CGFloat(10 + stage * 2), grow: treeGrown ? 1 : 0.15)
                            .offset(y: -5)
                    }
                    .frame(width: 60, height: 70, alignment: .bottom)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(habit.name) plant · stage \(stage) of 6").font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                        Text(HabitStats.insight(habit, logs: mine)).font(.isle(.footnote, .semibold)).foregroundStyle(T.ink)
                    }
                    Spacer(minLength: 0)
                }
                .card(fill: T.sky)

                VStack(spacing: 0) {
                    ToggleSwitch(label: "Remind me" + (habit.timeMinutes.map { " at \(Fmt.clock($0))" } ?? ""), isOn: $habit.remind)
                    Divider().overlay(T.line)
                    ToggleSwitch(label: "Pause for holiday (streak safe)", isOn: $habit.paused)
                    if !habit.lowBatteryVersion.isEmpty {
                        Divider().overlay(T.line)
                        HStack {
                            Text("Low-battery version").font(.isle(.subheadline)).foregroundStyle(T.ink)
                            Spacer()
                            Text(habit.lowBatteryVersion).font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))

                Button("Delete habit") { confirmDelete = true }
                    .font(.isle(.subheadline)).foregroundStyle(T.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .confirmationDialog("Delete \(habit.name) and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            Feedback.play(.whoosh)
                            let store = Store(context: context)
                            dismiss()
                            store.delete(habit)
                        }
                    }
            }
            .padding(16)
        }
        .screenBackground()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) { treeGrown = true }
            Feedback.play(.bloom(stage), after: 0.35)
        }
        .onChange(of: habit.paused) { _, p in
            if p {
                // freeze the rest of this week so the streak survives
                let today = Day.today
                let existing = Set(frozenDays.map { $0.dayKey })
                for d in Day.week(Day.weekStart(today)) where d >= today && !existing.contains(d) {
                    context.insert(FreezeDay(dayKey: d))
                }
            }
            try? context.save()
        }
        .sheet(isPresented: $editing) { HabitEditView(habit: habit).environment(app) }
    }

    private var subtitle: String {
        var bits: [String] = []
        bits.append(habit.isDaily ? "Every day" : "\(habit.targetPerWeek)× a week")
        if let t = habit.timeMinutes { bits.append(Fmt.clock(t)) }
        bits.append(Fmt.duration(habit.minutes))
        return bits.joined(separator: " · ")
    }

    private func stat(_ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(big).font(.isle(.title2, .heavy)).foregroundStyle(T.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(small).font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 10)
    }

    private func legend(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 10, height: 10)
            Text(text).font(.isle(.caption2, .heavy)).foregroundStyle(T.muted)
        }
    }

    private func heatmap(_ mine: [HabitLog], frozen: Set<Int>) -> some View {
        let thisWeek = Day.weekStart(Day.today)
        let weeks = (0..<12).map { Day.add(thisWeek, days: -7 * (11 - $0)) }
        let byDay = Dictionary(mine.map { ($0.dayKey, $0.kind) }, uniquingKeysWith: { a, _ in a })
        return HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Day.letters[i]).font(.isle(.caption2, .heavy)).foregroundStyle(T.muted).frame(height: 16)
                }
            }
            HStack(spacing: 4) {
                ForEach(weeks, id: \.self) { w in
                    VStack(spacing: 4) {
                        ForEach(Day.week(w), id: \.self) { d in
                            let kind = byDay[d]
                            let future = d > Day.today
                            let fill: Color = kind == .done ? T.habit(habit.colorIndex) : (kind == .lowBattery ? T.habit(habit.colorIndex).opacity(0.4) : (frozen.contains(d) ? T.line : T.surface2))
                            Button {
                                Feedback.play(kind == nil ? .tap : .chip(Day.weekday(d)))
                                selected = selected == d ? nil : d
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(future ? Color.clear : fill)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected == d ? T.outline : Color.clear, lineWidth: 2))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 16)
                            }
                            .buttonStyle(.plain)
                            .disabled(future)
                            .accessibilityLabel("\(Day.title(d)): \(kind == .done ? "done" : kind == .lowBattery ? "low-battery version" : "not done")")
                        }
                    }
                }
            }
        }
    }

    private func selectedText(_ mine: [HabitLog], frozen: Set<Int>) -> String? {
        guard let d = selected else { return nil }
        if let l = mine.first(where: { $0.dayKey == d }) {
            return "\(Day.shortName(d)) \(Day.dayMonth(d)): " + (l.kind == .lowBattery ? "low-battery version" : "done at \(Fmt.clock(l.minuteOfDay))")
        }
        if frozen.contains(d) { return "\(Day.shortName(d)) \(Day.dayMonth(d)): paused" }
        return "\(Day.shortName(d)) \(Day.dayMonth(d)): rest day"
    }
}
