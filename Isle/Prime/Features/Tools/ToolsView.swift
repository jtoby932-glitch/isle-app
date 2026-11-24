import SwiftUI
import SwiftData
import UIKit

/// The gym toolbox: plates, 1RM percentages, interval timer, cardio, body and recovery.
struct ToolsView: View {
    @Query private var profiles: [UserProfile]
    private var unit: WeightUnit { profiles.first?.weightUnit ?? .kg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calculators").eyebrow()
                NavigationLink { PlateCalculatorView(unit: unit) } label: {
                    toolRow("circle.grid.2x1.fill", "Plate calculator", "What to load on each side of the bar")
                }
                NavigationLink { OneRepMaxView(unit: unit) } label: {
                    toolRow("percent", "1RM and percentages", "Your max from any set, and weights for every %")
                }
                NavigationLink { IntervalTimerView() } label: {
                    toolRow("timer", "Interval timer", "EMOM, Tabata or your own work and rest")
                }
                Text("Track").eyebrow().padding(.top, 8)
                NavigationLink(value: Route.cardio) {
                    toolRow("figure.run", "Cardio", "Runs, rides, rows and walks")
                }
                NavigationLink(value: Route.measurements) {
                    toolRow("ruler", "Body measurements", "Waist, arms, chest and more over time")
                }
                NavigationLink(value: Route.recovery) {
                    toolRow("bolt.heart", "Recovery", "Which muscles are fresh and which need a rest")
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .buttonStyle(PressableStyle())
        .primeBackground()
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.large)
    }

    private func toolRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            IconBubble(symbol: symbol, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.primeHeadline).foregroundStyle(Theme.textPrimary)
                Text(detail).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
        }
        .primeCard(padding: 14)
    }
}

// MARK: - Plate calculator

struct PlateCalculatorView: View {
    let unit: WeightUnit
    @Environment(\.motion) private var motion
    @AppStorage("prime.plates.target") private var targetKg: Double = 100
    @AppStorage("prime.plates.bar") private var barIndex = 0
    @AppStorage("prime.plates.off") private var offRaw = ""
    @State private var targetText = ""
    @FocusState private var editing: Bool

    private var bars: [Double] { unit == .kg ? [20, 15, 10, 0] : [45, 35, 25, 0] }
    private var allPlates: [Double] { unit == .kg ? [25, 20, 15, 10, 5, 2.5, 1.25] : [45, 35, 25, 10, 5, 2.5] }
    private var off: Set<String> { Set(offRaw.split(separator: ",").map(String.init)) }
    private var plates: [Double] { allPlates.filter { !off.contains(Format.number($0)) } }
    private var bar: Double { bars[min(max(0, barIndex), bars.count - 1)] }
    private var target: Double { unit.fromKilograms(targetKg) }

    /// Greedy is exact for standard plate sets.
    private var load: (perSide: [Double], made: Double) {
        var remaining = max(0, (target - bar) / 2)
        var out: [Double] = []
        for p in plates.sorted(by: >) {
            while remaining + 0.0001 >= p {
                out.append(p)
                remaining -= p
                if out.count > 30 { break }
            }
        }
        return (out, bar + out.reduce(0, +) * 2)
    }

    var body: some View {
        let result = load
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Target").eyebrow()
                    HStack(spacing: 14) {
                        stepButton("minus") { setTarget(target - unit.increment) }
                        TextField("0", text: $targetText)
                            .keyboardType(.decimalPad)
                            .focused($editing)
                            .multilineTextAlignment(.center)
                            .font(.primeDisplay(48))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: 170)
                            .onSubmit(commitText)
                        stepButton("plus") { setTarget(target + unit.increment) }
                    }
                    Text(unit.symbol).font(.headline).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .primeHero()

                BarbellView(plates: result.perSide, unit: unit)
                    .frame(height: 150)
                    .animation(motion.animation(.spring(response: 0.45, dampingFraction: 0.75)), value: result.perSide)
                    .primeCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Each side").eyebrow()
                    if result.perSide.isEmpty {
                        Text(target <= bar ? "Just the bar." : "Nothing fits with these plates.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    } else {
                        let counts = Dictionary(grouping: result.perSide, by: { $0 }).map { ($0.key, $0.value.count) }.sorted { $0.0 > $1.0 }
                        ForEach(counts.indices, id: \.self) { i in
                            let plate = counts[i].0
                            let count = counts[i].1
                            HStack {
                                Circle().fill(BarbellView.color(for: plate, unit: unit)).frame(width: 14, height: 14)
                                Text("\(Format.number(plate)) \(unit.symbol)").font(.headline).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("× \(count)").font(.headline.monospacedDigit()).foregroundStyle(Theme.accentHighlight)
                            }
                        }
                    }
                    if abs(result.made - target) > 0.01 {
                        Label("Closest you can load is \(Format.number(result.made)) \(unit.symbol).", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                    }
                }
                .primeCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Bar").eyebrow()
                    Picker("Bar", selection: $barIndex) {
                        ForEach(bars.indices, id: \.self) { i in
                            Text(bars[i] == 0 ? "None" : "\(Format.number(bars[i])) \(unit.symbol)").tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Plates you have").eyebrow().padding(.top, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allPlates, id: \.self) { p in
                                let key = Format.number(p)
                                Chip(title: key, isSelected: !off.contains(key)) { togglePlate(key) }
                            }
                        }
                    }
                }
                .primeCard()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .primeBackground()
        .navigationTitle("Plate calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { commitText(); editing = false }
            }
        }
        .onAppear { targetText = Format.number(target) }
        .onChange(of: editing) { _, now in if !now { commitText() } }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.field))
        }
        .buttonStyle(PressableStyle())
    }

    private func setTarget(_ value: Double) {
        let clamped = min(max(0, value), unit == .kg ? 500 : 1100)
        targetKg = unit.toKilograms(clamped)
        targetText = Format.number(clamped)
    }

    private func commitText() {
        let cleaned = targetText.replacingOccurrences(of: ",", with: ".")
        if let v = Double(cleaned) { setTarget(v) } else { targetText = Format.number(target) }
    }

    private func togglePlate(_ key: String) {
        Haptics.tap()
        var s = off
        if s.contains(key) { s.remove(key) } else { s.insert(key) }
        offRaw = s.sorted().joined(separator: ",")
    }
}

/// A side-on barbell with the plates for one side, mirrored.
struct BarbellView: View {
    let plates: [Double]
    let unit: WeightUnit

    static func color(for plate: Double, unit: WeightUnit) -> Color {
        let kg = unit == .kg ? plate : plate * WeightUnit.kilogramsPerPound
        switch kg {
        case 22...: return Color(hex: 0xE5484D)
        case 18..<22: return Color(hex: 0x3D7BFF)
        case 13..<18: return Color(hex: 0xF5C542)
        case 9..<13: return Color(hex: 0x3DD9A4)
        case 4..<9: return Color(hex: 0xE8EDF5)
        case 2..<4: return Color(hex: 0x2A2F3A)
        default: return Color(hex: 0x9AA4B2)
        }
    }

    private func height(_ plate: Double) -> CGFloat {
        let kg = unit == .kg ? plate : plate * WeightUnit.kilogramsPerPound
        return 40 + CGFloat(min(kg, 25) / 25) * 90
    }

    private func width(_ plate: Double) -> CGFloat {
        let kg = unit == .kg ? plate : plate * WeightUnit.kilogramsPerPound
        return kg >= 10 ? 13 : 9
    }

    var body: some View {
        HStack(spacing: 0) {
            side(mirrored: true)
            Capsule().fill(LinearGradient(colors: [Color(hex: 0xC9D1DC), Color(hex: 0x7C8798)], startPoint: .top, endPoint: .bottom))
                .frame(height: 9)
                .frame(maxWidth: .infinity)
            side(mirrored: false)
        }
        .padding(.horizontal, 4)
        .accessibilityElement()
        .accessibilityLabel(plates.isEmpty ? "Empty bar" : "Each side: " + plates.map { Format.number($0) }.joined(separator: ", "))
    }

    private func side(mirrored: Bool) -> some View {
        let order = mirrored ? Array(plates.reversed()) : plates
        return HStack(spacing: 2) {
            if !mirrored { collar }
            ForEach(Array(order.enumerated()), id: \.offset) { _, p in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.color(for: p, unit: unit))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.25), lineWidth: 1))
                    .frame(width: width(p), height: height(p))
                    .transition(.move(edge: mirrored ? .leading : .trailing).combined(with: .opacity))
            }
            if mirrored { collar }
        }
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x9AA4B2)).frame(width: 6, height: 26)
    }
}

// MARK: - 1RM

struct OneRepMaxView: View {
    let unit: WeightUnit
    @Environment(TrainingStore.self) private var store
    @State private var weightText = ""
    @State private var reps = 5
    @FocusState private var editing: Bool

    private var weight: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    private var oneRM: Double? { weight.flatMap { StrengthMath.estimatedOneRepMax(weight: $0, reps: reps) } }

    /// Best estimated max per lift from history, strongest first.
    private var bests: [(name: String, max: Double)] {
        var best: [String: (String, Double)] = [:]
        for s in store.history.samples {
            guard let e = s.estimatedOneRepMax else { continue }
            if e > (best[s.exerciseSlug]?.1 ?? 0) { best[s.exerciseSlug] = (s.exerciseName, e) }
        }
        return best.values.sorted { $0.1 > $1.1 }.prefix(6).map { (name: $0.0, max: $0.1) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight (\(unit.symbol))").eyebrow()
                            TextField("0", text: $weightText)
                                .keyboardType(.decimalPad)
                                .focused($editing)
                                .font(.primeDisplay(30))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .frame(height: 56)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.field))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reps").eyebrow()
                            Stepper(value: $reps, in: 1...20) {
                                Text("\(reps)").font(.primeDisplay(30)).foregroundStyle(Theme.textPrimary).monospacedDigit()
                            }
                            .frame(height: 56)
                        }
                    }
                    if let oneRM {
                        VStack(spacing: 2) {
                            Text("Estimated 1RM").eyebrow()
                            Text("\(Format.number(round(oneRM))) \(unit.symbol)")
                                .font(.primeDisplay(44))
                                .foregroundStyle(Theme.textPrimary)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
                .primeHero()

                if let oneRM {
                    VStack(spacing: 0) {
                        HStack {
                            Text("%").frame(width: 50, alignment: .leading)
                            Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
                            Text("About").frame(width: 70, alignment: .trailing)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 6)
                        ForEach(Array(stride(from: 100, through: 50, by: -5)), id: \.self) { pct in
                            let w = roundToPlate(oneRM * Double(pct) / 100)
                            let r = repsAt(weight: w, max: oneRM)
                            HStack {
                                Text("\(pct)%").font(.subheadline.weight(.bold)).foregroundStyle(pct >= 85 ? Theme.accentHighlight : Theme.textPrimary)
                                    .frame(width: 50, alignment: .leading)
                                Text("\(Format.number(w)) \(unit.symbol)").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(r == 1 ? "1 rep" : "\(r) reps").font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(.vertical, 7)
                            Divider().overlay(Theme.border)
                        }
                    }
                    .primeCard()
                }

                if !bests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your best estimates").eyebrow()
                        let list = bests
                        ForEach(list.indices, id: \.self) { i in
                            let b = list[i]
                            Button {
                                Haptics.tap()
                                weightText = Format.number(round(unit.fromKilograms(b.max)))
                                reps = 1
                            } label: {
                                HStack {
                                    Text(b.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                    Spacer()
                                    Text(Format.weight(b.max, unit: unit)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.accentHighlight)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .primeCard()
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .primeBackground()
        .navigationTitle("1RM and percentages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editing = false }
            }
        }
    }

    private func roundToPlate(_ value: Double) -> Double {
        let step = unit.increment
        return (value / step).rounded() * step
    }

    /// Inverse of Epley: how many reps that weight is roughly good for.
    private func repsAt(weight: Double, max: Double) -> Int {
        guard weight > 0, max > weight else { return 1 }
        return Swift.max(1, Int((30 * (max / weight - 1)).rounded()))
    }
}

// MARK: - Interval timer

struct IntervalTimerView: View {
    enum Preset: String, CaseIterable, Identifiable {
        case emom = "EMOM", tabata = "Tabata", custom = "Custom"
        var id: String { rawValue }
    }

    @AppStorage("prime.interval.work") private var work = 40
    @AppStorage("prime.interval.rest") private var rest = 20
    @AppStorage("prime.interval.rounds") private var rounds = 8
    @State private var preset: Preset = .custom
    @State private var startedAt: Date? = nil
    @State private var pausedElapsed: TimeInterval? = nil
    @State private var lastPhaseKey = ""

    private var cycle: Int { work + rest }
    private var total: Int { cycle * rounds }
    private var running: Bool { startedAt != nil && pausedElapsed == nil }

    private struct Phase: Equatable {
        var round: Int
        var isWork: Bool
        var remaining: Double
        var length: Double
        var finished: Bool
    }

    private func phase(at elapsed: Double) -> Phase {
        guard elapsed < Double(total) else { return Phase(round: rounds, isWork: false, remaining: 0, length: 1, finished: true) }
        let inCycle = elapsed.truncatingRemainder(dividingBy: Double(cycle))
        let round = Int(elapsed) / max(1, cycle) + 1
        if inCycle < Double(work) {
            return Phase(round: round, isWork: true, remaining: Double(work) - inCycle, length: Double(work), finished: false)
        }
        return Phase(round: round, isWork: false, remaining: Double(cycle) - inCycle, length: Double(max(1, rest)), finished: false)
    }

    private func elapsed(at date: Date) -> Double {
        if let pausedElapsed { return pausedElapsed }
        guard let startedAt else { return 0 }
        return date.timeIntervalSince(startedAt)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Preset", selection: $preset) {
                    ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(startedAt != nil)
                .onChange(of: preset) { _, p in apply(p) }

                TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                    let e = elapsed(at: timeline.date)
                    let p = phase(at: e)
                    ring(p)
                        .onChange(of: "\(p.round)-\(p.isWork)-\(p.finished)-\(Int(p.remaining.rounded(.up)))") { _, key in cue(p, key: key) }
                }
                .frame(height: 300)

                HStack(spacing: 12) {
                    if startedAt != nil {
                        Button("Reset") { reset() }.buttonStyle(.prime(.secondary))
                    }
                    Button(running ? "Pause" : (startedAt == nil ? "Start" : "Resume")) { toggle() }
                        .buttonStyle(.prime(.primary))
                }

                if startedAt == nil {
                    VStack(spacing: 0) {
                        stepperRow("Work", value: $work, range: 5...600, step: 5)
                        Divider().overlay(Theme.border)
                        stepperRow("Rest", value: $rest, range: 0...600, step: 5)
                        Divider().overlay(Theme.border)
                        Stepper(value: $rounds, in: 1...60) {
                            HStack {
                                Text("Rounds").foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(rounds)").monospacedDigit().foregroundStyle(Theme.accentHighlight)
                            }
                        }
                        .padding(.vertical, 8)
                        Text("Total \(Format.clock(TimeInterval(total)))").font(.caption).foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .primeCard()
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .primeBackground()
        .navigationTitle("Interval timer")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func ring(_ p: Phase) -> some View {
        let tint = p.finished ? Theme.success : (p.isWork ? Theme.accent : Theme.warning)
        let progress = p.finished ? 1 : 1 - p.remaining / p.length
        return ZStack {
            Circle().stroke(Theme.field, lineWidth: 16)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
            VStack(spacing: 4) {
                Text(p.finished ? "DONE" : (startedAt == nil ? "READY" : (p.isWork ? "WORK" : "REST")))
                    .font(.headline.weight(.heavy)).tracking(3).foregroundStyle(tint)
                Text(p.finished ? "🔥" : "\(Int(p.remaining.rounded(.up)))")
                    .font(.primeDisplay(72)).foregroundStyle(Theme.textPrimary).monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text("Round \(min(p.round, rounds)) of \(rounds)").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(10)
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Format.clock(TimeInterval(value.wrappedValue))).monospacedDigit().foregroundStyle(Theme.accentHighlight)
            }
        }
        .padding(.vertical, 8)
    }

    private func apply(_ p: Preset) {
        switch p {
        case .emom: work = 60; rest = 0; rounds = 10
        case .tabata: work = 20; rest = 10; rounds = 8
        case .custom: break
        }
    }

    private func toggle() {
        Haptics.thud()
        if startedAt == nil {
            startedAt = Date()
            pausedElapsed = nil
            UIApplication.shared.isIdleTimerDisabled = true
        } else if let paused = pausedElapsed {
            startedAt = Date().addingTimeInterval(-paused)
            pausedElapsed = nil
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            pausedElapsed = elapsed(at: Date())
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func reset() {
        Haptics.tap()
        startedAt = nil
        pausedElapsed = nil
        lastPhaseKey = ""
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func cue(_ p: Phase, key: String) {
        guard running else { return }
        if p.finished {
            Haptics.success()
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        let phaseKey = "\(p.round)-\(p.isWork)"
        if phaseKey != lastPhaseKey {
            if !lastPhaseKey.isEmpty { Haptics.heavy() }
            lastPhaseKey = phaseKey
        } else {
            let left = Int(p.remaining.rounded(.up))
            if left <= 3 && left > 0 { Haptics.tap() }
        }
    }
}
