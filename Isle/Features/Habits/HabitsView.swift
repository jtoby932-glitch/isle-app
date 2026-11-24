import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @Query private var checkins: [DayCheckin]

    @State private var creating = false

    var body: some View {
        let weekStart = Day.weekStart(Day.today)
        let week = Day.week(weekStart)
        let low = (checkins.first { $0.dayKey == Day.today }?.battery ?? 2) <= 1
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habits").font(.isle(.largeTitle)).foregroundStyle(T.ink)
                        Text("Targets are per week, so a missed day never breaks anything.")
                            .font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                    }
                    Spacer()
                    Button { Feedback.play(.lift); creating = true } label: { Image(systemName: "plus") }
                        .buttonStyle(IconButtonStyle(fill: T.primary))
                        .accessibilityLabel("New habit")
                }

                if habits.isEmpty {
                    VStack(spacing: 8) {
                        PipView(mood: .normal, size: 90)
                        Text("No habits yet").font(.isle(.headline)).foregroundStyle(T.ink)
                        Text("Plant one and it grows into something on your isle.")
                            .font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted)
                        Button("Plant a habit") { creating = true }.buttonStyle(ChunkyButtonStyle(height: 48))
                    }
                    .card(padding: 16)
                }

                ForEach(habits) { h in
                    let count = HabitStats.countInWeek(h, weekStart: weekStart, logs: logs)
                    let doneToday = logs.contains { $0.habitID == h.id && $0.dayKey == Day.today }
                    let canToday = h.allowed(onWeekday: Day.weekday(Day.today)) && !h.paused
                    HStack(spacing: 10) {
                        Button {
                            Feedback.play(.tap)
                            app.openHabit = h
                        } label: {
                            HStack(spacing: 10) {
                                PlantBadge(colorIndex: h.colorIndex, stage: HabitStats.plantStage(h, logs: logs))
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(h.name).font(.isle(.body, .heavy)).foregroundStyle(T.ink).lineLimit(1)
                                        if h.paused { IsleTag(text: "Paused") }
                                    }
                                    HStack(spacing: 4) {
                                        ForEach(week, id: \.self) { d in
                                            let done = logs.contains { $0.habitID == h.id && $0.dayKey == d }
                                            Circle()
                                                .fill(done ? T.habit(h.colorIndex) : T.surface)
                                                .overlay(Circle().strokeBorder(done ? T.outline : (h.allowed(onWeekday: Day.weekday(d)) ? T.habit(h.colorIndex) : T.line), lineWidth: 1.5))
                                                .frame(width: 11, height: 11)
                                        }
                                        Text("\(count)/\(h.targetPerWeek)")
                                            .font(.isle(.caption, .heavy)).foregroundStyle(count >= h.targetPerWeek ? T.good : T.muted)
                                            .padding(.leading, 4)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if canToday {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    Store(context: context).toggle(h, lowBattery: low)
                                }
                                if !doneToday { app.cheer() }
                            } label: {
                                CheckCircle(done: doneToday, color: T.habit(h.colorIndex)).frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(doneToday ? "Undo \(h.name) today" : "Done \(h.name) today")
                        }
                    }
                    .card(padding: 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $creating) {
            HabitEditView(habit: nil).environment(app)
        }
    }
}

struct PlantBadge: View {
    var colorIndex: Int
    var stage: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(T.habit(colorIndex).opacity(0.25))
            Ellipse().fill(T.soil).frame(width: 34, height: 9).offset(y: -4)
            PlantView(color: T.habit(colorIndex), height: CGFloat(14 + stage * 4), head: CGFloat(8 + stage), grow: 1)
                .offset(y: -8)
        }
        .frame(width: 46, height: 46)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(T.outline, lineWidth: 2))
        .accessibilityHidden(true)
    }
}
