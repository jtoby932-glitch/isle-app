import SwiftUI
import SwiftData

struct DayCompleteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @Query private var isles: [IsleState]
    @Query private var journal: [JournalEntry]

    @State private var run = 0
    @State private var grown: [Bool] = []
    @State private var shellsShown = 0
    @State private var streakFlip = false
    @State private var titleIn = false
    @State private var cardsIn = false
    @State private var line = ""
    @State private var saved = false

    private var today: Int { Day.today }

    private var plants: [Color] {
        var out: [Color] = []
        for l in logs where l.dayKey == today {
            if let h = habits.first(where: { $0.id == l.habitID }) { out.append(T.habit(h.colorIndex)) }
        }
        for t in tasks where t.doneDayKey == today { out.append(t.priority ? T.primary : T.habit(t.plantIndex + 4)) }
        return Array(out.prefix(6))
    }

    private var earned: Int {
        let h = logs.filter { $0.dayKey == today }.reduce(0) { $0 + ($1.kind == .lowBattery ? 20 : 10) }
        let t = tasks.filter { $0.doneDayKey == today }.reduce(0) { $0 + Rewards.shells(for: $1) }
        return h + t
    }

    private var streakDays: Int {
        var activeDays = Set(logs.map { $0.dayKey })
        for t in tasks { if let d = t.doneDayKey { activeDays.insert(d) } }
        var n = 0
        var d = today
        while activeDays.contains(d) && n < 3650 { n += 1; d = Day.add(d, days: -1) }
        return n
    }

    private var tomorrowLine: String {
        let tm = Day.add(today, days: 1)
        let count = tasks.filter { $0.dayKey == tm && !$0.isDone }.count
        let firstHabit = habits.first { !$0.paused && $0.allowed(onWeekday: Day.weekday(tm)) && $0.timeMinutes != nil }
        var bits = ["\(count) task\(count == 1 ? "" : "s")"]
        if let h = firstHabit, let t = h.timeMinutes { bits.append("\(h.name.lowercased()) \(Fmt.clock(t))") }
        return bits.joined(separator: " · ")
    }

    var body: some View {
        let ps = plants
        let streak = streakDays
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day grown!").font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(T.ink)
                    Text("\(Day.title(today)) · \(ps.count) new plant\(ps.count == 1 ? "" : "s")")
                        .font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(titleIn ? 1 : 0.6, anchor: .leading)
                .opacity(titleIn ? 1 : 0)

                ZStack(alignment: .bottom) {
                    Circle().fill(Color(hex: 0xFFB86B)).frame(width: 110, height: 110)
                        .offset(x: 100, y: titleIn ? -120 : -150)
                    Ellipse().fill(T.grass).frame(height: 70).overlay(Ellipse().strokeBorder(T.outline, lineWidth: 2.5))
                        .padding(.horizontal, 10)
                    Ellipse().fill(T.soil).frame(width: 190, height: 34).overlay(Ellipse().strokeBorder(T.outline, lineWidth: 2.5))
                        .offset(x: 40, y: -18)
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Array(ps.enumerated()), id: \.offset) { i, c in
                            PlantView(color: c, height: CGFloat([86, 118, 96, 70, 104, 80][i % 6]), head: CGFloat([24, 30, 26, 20, 28, 22][i % 6]),
                                      grow: (grown.count > i && grown[i]) ? 1 : 0.02)
                        }
                    }
                    .offset(x: 40, y: -30)
                    PipView(mood: .cheer, size: 120, colorIndex: isles.first?.bodyColorIndex ?? 0, outfit: isles.first?.outfit ?? "none")
                        .offset(x: -100, y: -20)
                }
                .frame(height: 260)
                .clipped()

                HStack(spacing: 8) {
                    statCard("+\(shellsShown)", "shells")
                    statCard("\(streakFlip ? streak : max(0, streak - 1))", "day streak")
                        .rotation3DEffect(.degrees(streakFlip ? 0 : 90), axis: (x: 1, y: 0, z: 0))
                    statCard("\(ps.count)", "new plants")
                }
                .opacity(cardsIn ? 1 : 0)
                .offset(y: cardsIn ? 0 : 16)

                HStack(spacing: 10) {
                    Image(systemName: "sun.max").font(.system(size: 20, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12).fill(T.sky))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.outline, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tomorrow").font(.isle(.subheadline, .heavy))
                        Text(tomorrowLine).font(.isle(.caption, .bold)).foregroundStyle(T.muted)
                    }
                    Spacer()
                }
                .foregroundStyle(T.ink)
                .card()
                .opacity(cardsIn ? 1 : 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text("One line about today?").font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                    HStack(spacing: 8) {
                        TextField("Gym before work again. Felt good.", text: $line)
                            .font(.isle(.subheadline, .semibold))
                            .padding(.horizontal, 12).frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                            .onChange(of: line) { _, _ in saved = false }
                        Button(saved ? "Saved" : "Save") { saveLine() }
                            .buttonStyle(PillButtonStyle(fill: saved ? T.goodSoft : T.surface, height: 48))
                    }
                }
                .opacity(cardsIn ? 1 : 0)

                HStack(spacing: 8) {
                    Button("Replay") { play() }
                        .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 52, shadow: false))
                        .frame(width: 120)
                    Button("Goodnight, \(isles.first?.pipName ?? "Pip")") { saveLine(); dismiss() }
                        .buttonStyle(ChunkyButtonStyle(height: 52))
                }
            }
            .padding(16)
        }
        .background(Color.dynamic(0xFFE9C9, 0x2A2140).ignoresSafeArea())
        .onAppear {
            line = journal.first { $0.dayKey == today }?.text ?? ""
            saved = !line.isEmpty
            play()
        }
    }

    private func statCard(_ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(big).font(.isle(.title2, .heavy)).foregroundStyle(T.ink).monospacedDigit()
                .contentTransition(.numericText())
            Text(small).font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 10)
    }

    private func play() {
        run += 1
        let token = run
        let count = plants.count
        let target = earned
        grown = Array(repeating: false, count: count)
        shellsShown = 0
        streakFlip = false
        titleIn = false
        cardsIn = false
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { titleIn = true }
        Feedback.play(.chirp, after: 0.15)
        for i in 0..<count {
            let delay = 0.4 + Double(i) * 0.3
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard run == token, grown.count > i else { return }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) { grown[i] = true }
                Feedback.play(.bloom(i))
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard run == token else { return }
            withAnimation(.easeOut(duration: 0.45)) { cardsIn = true }
            var k = 0
            while shellsShown < target && run == token {
                try? await Task.sleep(nanoseconds: 40_000_000)
                withAnimation(.linear(duration: 0.04)) { shellsShown = min(target, shellsShown + 3) }
                Feedback.play(.count(k))
                k += 1
            }
            guard run == token else { return }
            Feedback.play(.shell)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { streakFlip = true }
            Feedback.play(.tick, after: 0.1)
            Feedback.play(.celebrate, after: 0.4)
        }
    }

    private func saveLine() {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if let existing = journal.first(where: { $0.dayKey == today }) {
            existing.text = t
        } else {
            context.insert(JournalEntry(dayKey: today, text: t))
        }
        try? context.save()
        if !saved { Feedback.play(.tick) }
        saved = true
    }
}
