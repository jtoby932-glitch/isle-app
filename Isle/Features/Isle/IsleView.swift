import SwiftUI
import SwiftData

struct IsleView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @Query private var settingsRows: [AppSettings]
    @Query private var isles: [IsleState]

    @State private var weekOffset = 0
    @State private var selected: Int = Day.weekday(Day.today)
    @State private var waves = false

    private static let plots: [CGPoint] = [
        CGPoint(x: 105, y: 150), CGPoint(x: 175, y: 110), CGPoint(x: 255, y: 120), CGPoint(x: 305, y: 190),
        CGPoint(x: 265, y: 265), CGPoint(x: 190, y: 290), CGPoint(x: 115, y: 250)
    ]

    private var weekStart: Int { Day.add(Day.weekStart(Day.today), days: weekOffset * 7) }
    private var days: [Int] { Day.week(weekStart) }
    private var settings: AppSettings? { settingsRows.first }
    private var isle: IsleState? { isles.first }

    struct PlotInfo {
        var plants: [Color]
        var seeds: Int
        var stormy: Bool
        var items: [(String, Color, Bool)]
    }

    private func info(_ d: Int, events: [CalEvent]) -> PlotInfo {
        var plants: [Color] = []
        var items: [(String, Color, Bool)] = []
        for l in logs where l.dayKey == d {
            if let h = habits.first(where: { $0.id == l.habitID }) {
                plants.append(T.habit(h.colorIndex))
                items.append((h.name, T.habit(h.colorIndex), true))
            }
        }
        var seeds = 0
        for t in tasks {
            let doneHere = t.isDone && (t.doneDayKey ?? t.dayKey) == d
            if doneHere {
                plants.append(t.priority ? T.primary : T.habit(t.plantIndex + 4))
                items.append((t.title, T.habit(4), true))
            } else if t.dayKey == d && !t.isDone {
                seeds += 1
                items.append((t.title, T.habit(4), false))
            }
        }
        let load = Planner.load(day: d, tasks: tasks, habits: habits, events: events)
        let cap = settings?.capacity(forWeekday: Day.weekday(d)) ?? 420
        return PlotInfo(plants: plants, seeds: seeds, stormy: load > cap && d >= Day.today, items: items)
    }

    var body: some View {
        let evs = CalendarService.shared.events(for: days, enabled: settings?.calendarOn ?? false)
        let infos = days.map { info($0, events: evs) }
        let grown = infos.reduce(0) { $0 + $1.plants.count }
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week \(Day.weekNumber(weekStart)) Isle").font(.isle(.largeTitle)).foregroundStyle(T.ink)
                        Text("\(Day.weekRange(weekStart)) · \(grown) plant\(grown == 1 ? "" : "s") grown")
                            .font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink.opacity(0.8))
                    }
                    Spacer()
                    Button { Feedback.play(.tap); withAnimation { weekOffset -= 1 } } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Previous week's isle")
                    if weekOffset < 0 {
                        Button { Feedback.play(.tap); withAnimation { weekOffset += 1 } } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(IconButtonStyle()).accessibilityLabel("Next week's isle")
                    }
                }

                GeometryReader { g in
                    let s = g.size.width / 390
                    ZStack(alignment: .topLeading) {
                        IslandShape(scale: s, waves: waves)
                        ForEach(0..<7, id: \.self) { i in
                            plot(i, info: infos[i], scale: s)
                        }
                        let p = IsleView.plots[selected]
                        PipView(mood: infos[selected].stormy ? .normal : .happy, size: 56 * s,
                                colorIndex: isle?.bodyColorIndex ?? 0, outfit: isle?.outfit ?? "none")
                            .position(x: (p.x - 52) * s, y: (p.y - 34) * s)
                            .animation(.easeInOut(duration: 0.7), value: selected)
                            .allowsHitTesting(false)
                        if infos[3].stormy || infos.contains(where: { $0.stormy }) {
                            ForEach(0..<7, id: \.self) { i in
                                if infos[i].stormy {
                                    StormCloud()
                                        .frame(width: 60 * s, height: 46 * s)
                                        .position(x: IsleView.plots[i].x * s, y: (IsleView.plots[i].y - 58) * s)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                .aspectRatio(390.0 / 400.0, contentMode: .fit)
                .background(RoundedRectangle(cornerRadius: 24).fill(T.sea))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(T.outline, lineWidth: 2))

                dayCard(days[selected], info: infos[selected], events: evs)

                HStack(spacing: 8) {
                    Button { app.showShop = true } label: { Label("Shell Shop", systemImage: "bag") }
                        .buttonStyle(ChunkyButtonStyle(fill: T.surface, textColor: T.ink, height: 48, shadow: false))
                    Button { app.showSunday = true } label: { Label("Plan", systemImage: "sparkles") }
                        .buttonStyle(ChunkyButtonStyle(height: 48, shadow: false))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(T.sky.ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { waves = true }
        }
    }

    private func plot(_ i: Int, info: PlotInfo, scale s: CGFloat) -> some View {
        let d = days[i]
        let on = selected == i
        let isToday = d == Day.today
        let p = IsleView.plots[i]
        return Button {
            if selected != i {
                Feedback.play(.place(i))
                Feedback.play(.chirp, after: 0.65)
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { selected = i }
        } label: {
            VStack(spacing: 2 * s) {
                HStack(alignment: .bottom, spacing: 3 * s) {
                    ForEach(Array(info.plants.prefix(4).enumerated()), id: \.offset) { j, c in
                        SwayingPlant(color: c, height: (j < 2 ? 26 : 20) * s, head: (j < 2 ? 12 : 9) * s, delay: Double(j) * 0.4)
                    }
                }
                .frame(height: 28 * s, alignment: .bottom)
                .offset(y: 8 * s)
                ZStack {
                    Ellipse().fill(info.stormy ? T.soilWet : T.soil)
                    Ellipse().strokeBorder(T.pipInk, lineWidth: 2.5)
                    HStack(spacing: 4 * s) {
                        ForEach(0..<min(6, info.seeds), id: \.self) { _ in
                            Circle().fill(Color(hex: 0x5C3A22)).frame(width: 6 * s, height: 6 * s)
                        }
                    }
                }
                .frame(width: 72 * s, height: 40 * s)
                .shadow(color: on ? T.primary.opacity(0.9) : .clear, radius: on ? 0 : 0)
                .overlay(Ellipse().stroke(T.primary, lineWidth: on ? 5 : 0).padding(-4))
                Text(Day.shortName(d))
                    .font(.system(size: 12 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(T.primaryInk)
                    .padding(.horizontal, 8 * s)
                    .frame(height: 20 * s)
                    .background(Capsule().fill(on ? T.primary : (isToday ? Color(hex: 0xFFF1C2) : (info.stormy ? Color(hex: 0xDDE3EE) : .white))))
                    .overlay(Capsule().strokeBorder(T.pipInk, lineWidth: 2))
            }
            .scaleEffect(on ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .position(x: p.x * s, y: (p.y - 6) * s)
        .accessibilityLabel("\(Day.longName(d)): \(info.plants.count) grown, \(info.seeds) planned\(info.stormy ? ", overloaded" : "")")
    }

    private func dayCard(_ d: Int, info: PlotInfo, events: [CalEvent]) -> some View {
        let doneCount = info.items.filter { $0.2 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Day.longName(d) + (d == Day.today ? " · today" : "")).font(.isle(.title3, .heavy)).foregroundStyle(T.ink)
                Spacer()
                Text(info.stormy ? "Stormy" : (info.items.isEmpty ? "Nothing planned" : "\(doneCount) grown, \(info.items.count - doneCount) to go"))
                    .font(.isle(.caption, .heavy)).foregroundStyle(info.stormy ? T.warnText : T.muted)
            }
            ForEach(Array(info.items.prefix(4).enumerated()), id: \.offset) { _, it in
                HStack(spacing: 8) {
                    Circle().fill(it.1).overlay(Circle().strokeBorder(T.outline, lineWidth: 1.5)).frame(width: 10, height: 10)
                    Text(it.0).font(.isle(.subheadline, .heavy)).foregroundStyle(it.2 ? T.muted : T.ink).strikethrough(it.2)
                    Spacer()
                }
            }
            if info.stormy {
                Button("Clear the storm") { clearStorm(d, events: events) }
                    .buttonStyle(ChunkyButtonStyle(height: 44, shadow: false))
            }
        }
        .card(shadow: true)
    }

    private func clearStorm(_ d: Int, events: [CalEvent]) {
        var loads: [Int: Int] = [:]
        for x in days { loads[x] = Planner.load(day: x, tasks: tasks, habits: habits, events: events) }
        let moves = Planner.fix(day: d, week: days, tasks: tasks, loads: loads,
                                capacity: { settings?.capacity(forWeekday: Day.weekday($0)) ?? 420 })
        guard !moves.isEmpty else {
            Feedback.play(.hmm)
            app.showToast("Nothing small enough to move from \(Day.longName(d)).")
            return
        }
        Feedback.play(.whoosh)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            for (t, nd) in moves { t.dayKey = nd }
        }
        try? context.save()
        if let first = moves.first { Feedback.play(.place(Day.weekday(first.1)), after: 0.3) }
        Feedback.play(.celebrate, after: 0.65)
    }
}

struct SwayingPlant: View {
    var color: Color
    var height: CGFloat
    var head: CGFloat
    var delay: Double
    @State private var sway = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PlantView(color: color, height: height, head: head)
            .rotationEffect(.degrees(sway ? 4 : -4), anchor: .bottom)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3 + delay).repeatForever(autoreverses: true).delay(delay)) { sway = true }
            }
    }
}

struct StormCloud: View {
    @State private var rain = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    var p = Path()
                    p.addEllipse(in: CGRect(x: size.width * 0.05, y: size.height * 0.25, width: size.width * 0.45, height: size.height * 0.45))
                    p.addEllipse(in: CGRect(x: size.width * 0.28, y: size.height * 0.05, width: size.width * 0.45, height: size.height * 0.55))
                    p.addEllipse(in: CGRect(x: size.width * 0.5, y: size.height * 0.22, width: size.width * 0.45, height: size.height * 0.45))
                    ctx.fill(p, with: .color(Color(hex: 0xB9C3D6)))
                    ctx.stroke(p, with: .color(T.pipInk), lineWidth: 2)
                }
                .frame(width: w, height: h * 0.7)
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(Color(hex: 0x3E7CC2))
                        .frame(width: 3, height: 8)
                        .offset(x: w * (0.3 + 0.18 * CGFloat(i)), y: h * 0.7 + (rain ? 10 : 0))
                        .opacity(rain ? 0 : 1)
                        .animation(.linear(duration: 0.8).repeatForever(autoreverses: false).delay(Double(i) * 0.25), value: rain)
                }
            }
        }
        .onAppear { rain = true }
        .accessibilityHidden(true)
    }
}

/// The island itself: sand, grass, the dotted path, a palm, waves.
struct IslandShape: View {
    var scale: CGFloat
    var waves: Bool

    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            c.scaleBy(x: scale, y: scale)
            let ink = T.pipInk
            // waves
            var w = Path()
            for (x, y) in [(18.0, 40.0), (14.0, 330.0), (320.0, 360.0), (330.0, 30.0)] {
                w.move(to: CGPoint(x: x, y: y))
                w.addQuadCurve(to: CGPoint(x: x + 20, y: y), control: CGPoint(x: x + 10, y: y - 8))
                w.addQuadCurve(to: CGPoint(x: x + 40, y: y), control: CGPoint(x: x + 30, y: y + 8))
            }
            c.stroke(w, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            var sand = Path()
            sand.move(to: CGPoint(x: 40, y: 200))
            sand.addCurve(to: CGPoint(x: 200, y: 55), control1: CGPoint(x: 30, y: 110), control2: CGPoint(x: 120, y: 50))
            sand.addCurve(to: CGPoint(x: 360, y: 210), control1: CGPoint(x: 300, y: 60), control2: CGPoint(x: 372, y: 120))
            sand.addCurve(to: CGPoint(x: 190, y: 347), control1: CGPoint(x: 348, y: 300), control2: CGPoint(x: 270, y: 352))
            sand.addCurve(to: CGPoint(x: 40, y: 200), control1: CGPoint(x: 100, y: 342), control2: CGPoint(x: 50, y: 290))
            c.fill(sand, with: .color(Color(hex: 0xF6E3B4)))
            c.stroke(sand, with: .color(ink), lineWidth: 3)

            var grass = Path()
            grass.move(to: CGPoint(x: 66, y: 200))
            grass.addCurve(to: CGPoint(x: 200, y: 84), control1: CGPoint(x: 60, y: 128), control2: CGPoint(x: 132, y: 82))
            grass.addCurve(to: CGPoint(x: 330, y: 206), control1: CGPoint(x: 285, y: 87), control2: CGPoint(x: 338, y: 137))
            grass.addCurve(to: CGPoint(x: 190, y: 317), control1: CGPoint(x: 322, y: 280), control2: CGPoint(x: 256, y: 320))
            grass.addCurve(to: CGPoint(x: 66, y: 200), control1: CGPoint(x: 116, y: 314), control2: CGPoint(x: 72, y: 268))
            c.fill(grass, with: .color(Color(hex: 0xA6DE8F)))
            c.stroke(grass, with: .color(ink), lineWidth: 2.5)

            var trail = Path()
            let pts = IsleViewPlots.points
            trail.move(to: pts[0])
            for p in pts.dropFirst() { trail.addLine(to: p) }
            c.stroke(trail, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10]))

            // palm
            var trunk = Path()
            trunk.move(to: CGPoint(x: 196, y: 205))
            trunk.addQuadCurve(to: CGPoint(x: 196, y: 161), control: CGPoint(x: 200, y: 185))
            c.stroke(trunk, with: .color(Color(hex: 0x8A5A3B)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            var fronds = Path()
            let top = CGPoint(x: 196, y: 161)
            for (cx, cy, ex, ey) in [(-20.0, -12.0, -30.0, 4.0), (20.0, -14.0, 30.0, 2.0), (-6.0, -20.0, -20.0, -22.0), (8.0, -20.0, 22.0, -20.0)] {
                fronds.move(to: top)
                fronds.addQuadCurve(to: CGPoint(x: top.x + ex, y: top.y + ey), control: CGPoint(x: top.x + cx, y: top.y + cy))
            }
            c.stroke(fronds, with: .color(Color(hex: 0x4E9E46)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        .offset(x: waves ? 3 : -3)
        .accessibilityHidden(true)
    }
}

enum IsleViewPlots {
    static let points: [CGPoint] = [
        CGPoint(x: 105, y: 150), CGPoint(x: 175, y: 110), CGPoint(x: 255, y: 120), CGPoint(x: 305, y: 190),
        CGPoint(x: 265, y: 265), CGPoint(x: 190, y: 290), CGPoint(x: 115, y: 250)
    ]
}
