import Charts
import SwiftData
import SwiftUI

// Cardio and body measurements live in their own small database next to PRIME's,
// so PRIME's main store and its migrations stay untouched.

@Model
final class CardioEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = CardioKind.run.rawValue
    var minutes: Double = 30
    /// Always kilometres; shown in miles for imperial users.
    var distanceKm: Double? = nil
    var notes: String = ""

    init(date: Date, kind: CardioKind, minutes: Double, distanceKm: Double?, notes: String) {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
        self.minutes = minutes
        self.distanceKm = distanceKm
        self.notes = notes
    }

    var kind: CardioKind { CardioKind(rawValue: kindRaw) ?? .other }
}

enum CardioKind: String, CaseIterable, Identifiable {
    case run, walk, bike, row, swim, stairs, other
    var id: String { rawValue }
    var name: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .bike: return "Bike"
        case .row: return "Row"
        case .swim: return "Swim"
        case .stairs: return "Stairs"
        case .other: return "Other"
        }
    }
    var symbol: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "figure.outdoor.cycle"
        case .row: return "figure.rower"
        case .swim: return "figure.pool.swim"
        case .stairs: return "figure.stair.stepper"
        case .other: return "heart.fill"
        }
    }
    var hasPace: Bool { self == .run || self == .walk }
}

@Model
final class BodyMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var partRaw: String = MeasurePart.waist.rawValue
    /// Centimetres, or percent for body fat.
    var value: Double = 0

    init(date: Date, part: MeasurePart, value: Double) {
        self.id = UUID()
        self.date = date
        self.partRaw = part.rawValue
        self.value = value
    }

    var part: MeasurePart { MeasurePart(rawValue: partRaw) ?? .waist }
}

enum MeasurePart: String, CaseIterable, Identifiable {
    case waist, chest, hips, shoulders, neck, arms, forearms, thighs, calves, bodyFat
    var id: String { rawValue }
    var name: String {
        switch self {
        case .bodyFat: return "Body fat"
        default: return rawValue.capitalized
        }
    }
    var isPercent: Bool { self == .bodyFat }
}

enum PrimeExtras {
    static let container: ModelContainer? = {
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        let config = ModelConfiguration("PRIMEExtras", schema: Schema([CardioEntry.self, BodyMeasurement.self]), cloudKitDatabase: .none)
        return try? ModelContainer(for: CardioEntry.self, BodyMeasurement.self, configurations: config)
    }()
}

/// Reads PRIME's profile for units, then shows the content against the extras database.
struct ExtrasHost<Content: View>: View {
    @Query private var profiles: [UserProfile]
    let content: (_ metric: Bool) -> Content

    init(@ViewBuilder content: @escaping (_ metric: Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        if let container = PrimeExtras.container {
            content(profiles.first?.measurementSystem != .imperial)
                .modelContainer(container)
        } else {
            MissingItemView(title: "Couldn't open this", message: "Close PRIME fully and try again.")
        }
    }
}

// MARK: - Cardio

struct CardioView: View {
    let metric: Bool
    @Environment(\.modelContext) private var context
    @Query(sort: \CardioEntry.date, order: .reverse) private var entries: [CardioEntry]
    @State private var adding = false

    private var distanceUnit: String { metric ? "km" : "mi" }
    private func shown(_ km: Double) -> Double { metric ? km : km / 1.609344 }

    private var weekStart: Date {
        Calendar.prime.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private struct WeekBar: Identifiable {
        let id: Date
        let minutes: Double
    }

    private var weeks: [WeekBar] {
        (0..<8).reversed().map { back in
            let start = Calendar.prime.date(byAdding: .weekOfYear, value: -back, to: weekStart) ?? weekStart
            let end = Calendar.prime.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let mins = entries.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.minutes }
            return WeekBar(id: start, minutes: mins)
        }
    }

    var body: some View {
        let thisWeek = entries.filter { $0.date >= weekStart }
        let minutes = thisWeek.reduce(0) { $0 + $1.minutes }
        let distance = thisWeek.compactMap(\.distanceKm).reduce(0, +)
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This week").eyebrow()
                    HStack(spacing: 0) {
                        stat("\(Int(minutes))", "minutes")
                        stat(Format.number(shown(distance), maxFractionDigits: 1), distanceUnit)
                        stat("\(thisWeek.count)", thisWeek.count == 1 ? "session" : "sessions")
                    }
                    Chart(weeks) { w in
                        BarMark(x: .value("Week", w.id, unit: .weekOfYear), y: .value("Minutes", w.minutes))
                            .foregroundStyle(w.id == weekStart ? Theme.accentGradient : LinearGradient(colors: [Theme.cardRaised, Theme.cardRaised], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(4)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Theme.border)
                            AxisValueLabel().foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .frame(height: 110)
                }
                .primeHero()

                if entries.isEmpty {
                    Text("Log runs, rides, rows and walks here. They count towards your week alongside your lifting.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                }

                ForEach(entries) { e in row(e) }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .primeBackground()
        .navigationTitle("Cardio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Log cardio")
            }
        }
        .sheet(isPresented: $adding) {
            AddCardioSheet(metric: metric) { entry in
                context.insert(entry)
                try? context.save()
                Haptics.success()
            }
            .presentationDetents([.large])
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.primeDisplay(28)).foregroundStyle(Theme.textPrimary).contentTransition(.numericText())
            Text(label).font(.primeCaption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ e: CardioEntry) -> some View {
        HStack(spacing: 12) {
            IconBubble(symbol: e.kind.symbol, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.kind.name).font(.primeHeadline).foregroundStyle(Theme.textPrimary)
                Text(e.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                if !e.notes.isEmpty {
                    Text(e.notes).font(.caption).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.clock(e.minutes * 60)).font(.headline.monospacedDigit()).foregroundStyle(Theme.textPrimary)
                if let d = e.distanceKm, d > 0 {
                    Text("\(Format.number(shown(d), maxFractionDigits: 2)) \(distanceUnit)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Theme.accentHighlight)
                    if e.kind.hasPace {
                        Text("\(Format.clock(e.minutes * 60 / shown(d))) /\(distanceUnit)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .primeCard(padding: 14)
        .contextMenu {
            Button(role: .destructive) {
                Haptics.warning()
                withAnimation { context.delete(e); try? context.save() }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

private struct AddCardioSheet: View {
    let metric: Bool
    var onSave: (CardioEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: CardioKind = .run
    @State private var minutes = 30
    @State private var distanceText = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CardioKind.allCases) { k in
                                Chip(title: k.name, symbol: k.symbol, isSelected: kind == k) {
                                    Haptics.selection()
                                    kind = k
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    Stepper(value: $minutes, in: 1...600, step: 1) {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text("\(minutes) min").monospacedDigit().foregroundStyle(Theme.accentHighlight)
                        }
                    }
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("Optional", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text(metric ? "km" : "mi").foregroundStyle(Theme.textSecondary)
                    }
                    DatePicker("When", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    TextField("Notes", text: $notes)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .primeBackground()
            .navigationTitle("Log cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let raw = Double(distanceText.replacingOccurrences(of: ",", with: "."))
                        let km = raw.map { metric ? $0 : $0 * 1.609344 }
                        onSave(CardioEntry(date: date, kind: kind, minutes: Double(minutes), distanceKm: km, notes: notes))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Measurements

struct MeasurementsView: View {
    let metric: Bool
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date) private var all: [BodyMeasurement]
    @State private var adding = false
    @State private var selected: MeasurePart? = nil

    private func shown(_ m: BodyMeasurement) -> Double { m.part.isPercent || metric ? m.value : m.value / 2.54 }
    private func unitLabel(_ p: MeasurePart) -> String { p.isPercent ? "%" : (metric ? "cm" : "in") }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if all.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "ruler").font(.system(size: 34)).foregroundStyle(Theme.accentHighlight)
                        Text("Measure every couple of weeks, same time of day. The scale doesn't show muscle; a tape does.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                        Button("Add measurements") { adding = true }.buttonStyle(.prime(.primary))
                    }
                    .padding(.vertical, 30)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(MeasurePart.allCases) { part in
                            let points = all.filter { $0.part == part }
                            if let last = points.last {
                                Button {
                                    Haptics.tap()
                                    withAnimation(.snappy) { selected = selected == part ? nil : part }
                                } label: { tile(part, points: points, last: last) }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    if let part = selected {
                        detail(part)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .primeBackground()
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add measurements")
            }
        }
        .sheet(isPresented: $adding) {
            AddMeasurementsSheet(metric: metric) { items in
                for m in items { context.insert(m) }
                try? context.save()
                Haptics.success()
            }
        }
    }

    private func tile(_ part: MeasurePart, points: [BodyMeasurement], last: BodyMeasurement) -> some View {
        let first = points.first ?? last
        let change = shown(last) - shown(first)
        return VStack(alignment: .leading, spacing: 6) {
            Text(part.name).eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Format.number(shown(last), maxFractionDigits: 1)).font(.primeDisplay(26)).foregroundStyle(Theme.textPrimary)
                Text(unitLabel(part)).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            if points.count > 1 {
                Label("\(change >= 0 ? "+" : "")\(Format.number(change, maxFractionDigits: 1)) since \(first.date.formatted(.dateTime.day().month(.abbreviated)))",
                      systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("First entry").font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .primeCard(selected == part ? .hero(Theme.accent) : .raised, padding: 14)
    }

    private func detail(_ part: MeasurePart) -> some View {
        let points = all.filter { $0.part == part }
        return VStack(alignment: .leading, spacing: 10) {
            Text(part.name).font(.primeTitle3).foregroundStyle(Theme.textPrimary)
            if points.count > 1 {
                Chart(points) { m in
                    LineMark(x: .value("Date", m.date), y: .value(part.name, shown(m)))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", m.date), y: .value(part.name, shown(m)))
                        .foregroundStyle(Theme.accentHighlight)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.textTertiary) }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.border)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 160)
            }
            ForEach(points.reversed()) { m in
                HStack {
                    Text(m.date.formatted(.dateTime.day().month(.abbreviated).year())).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Format.number(shown(m), maxFractionDigits: 1)) \(unitLabel(part))").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textPrimary)
                }
                .padding(.vertical, 3)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation { context.delete(m); try? context.save() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .primeCard()
    }
}

private struct AddMeasurementsSheet: View {
    let metric: Bool
    var onSave: ([BodyMeasurement]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var values: [MeasurePart: String] = [:]
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                .listRowBackground(Theme.card)
                Section {
                    ForEach(MeasurePart.allCases) { part in
                        HStack {
                            Text(part.name)
                            Spacer()
                            TextField("–", text: Binding(get: { values[part] ?? "" }, set: { values[part] = $0 }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                            Text(part.isPercent ? "%" : (metric ? "cm" : "in"))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 30, alignment: .leading)
                        }
                    }
                } footer: {
                    Text("Fill in only what you measured today.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .primeBackground()
            .navigationTitle("Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var out: [BodyMeasurement] = []
                        for part in MeasurePart.allCases {
                            guard let raw = values[part], let v = Double(raw.replacingOccurrences(of: ",", with: ".")), v > 0 else { continue }
                            let stored = part.isPercent || metric ? v : v * 2.54
                            out.append(BodyMeasurement(date: date, part: part, value: stored))
                        }
                        onSave(out)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Recovery

struct RecoveryView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.bodyModel) private var model
    @Environment(\.motion) private var motion
    @State private var side: AnatomySide = .front
    @State private var selection: MuscleGroup? = nil

    private struct Status {
        let muscle: MuscleGroup
        let hours: Double?
        let sets: Int

        var label: String {
            guard let hours else { return "Fresh" }
            switch hours {
            case ..<24: return "Just worked"
            case ..<48: return "Recovering"
            case ..<72: return "Nearly ready"
            default: return "Fresh"
            }
        }

        var heat: Double {
            guard let hours else { return 0 }
            return max(0, 1 - hours / 96)
        }
    }

    private var statuses: [Status] {
        let now = Date()
        let recent = store.history.samples(in: DateInterval(start: now.addingTimeInterval(-14 * 86_400), end: now))
        let fourDays = now.addingTimeInterval(-4 * 86_400)
        return MuscleGroup.allCases.map { m in
            let hits = recent.filter { $0.primaryMuscles.contains(m) }
            let last = hits.map(\.date).max()
            return Status(muscle: m,
                          hours: last.map { now.timeIntervalSince($0) / 3600 },
                          sets: hits.filter { $0.date >= fourDays }.count)
        }
        .sorted { ($0.hours ?? 9_999) > ($1.hours ?? 9_999) }
    }

    var body: some View {
        let list = statuses
        let emphasis = Dictionary(uniqueKeysWithValues: list.filter { $0.heat > 0 }.map { ($0.muscle, MuscleEmphasis.heat($0.heat)) })
        let fresh = list.filter { $0.label == "Fresh" }.map { $0.muscle.displayName }
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to train").eyebrow()
                    Text(fresh.isEmpty ? "Everything's still recovering. A light day or cardio fits." : fresh.prefix(6).joined(separator: ", "))
                        .font(.primeHeadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .primeHero(tint: Theme.success)

                ZStack(alignment: .topTrailing) {
                    InteractiveBodyView(side: side, model: model, emphasis: emphasis, selection: $selection)
                        .id(side)
                        .padding(.vertical, 8)
                    Button {
                        Haptics.tap()
                        withAnimation(motion.animation(.spring(response: 0.5, dampingFraction: 0.8))) { side = side == .front ? .back : .front }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Theme.cardRaised))
                    }
                    .accessibilityLabel("Turn the body around")
                }
                .frame(height: 380)
                .frame(maxWidth: .infinity)
                .primeCard()

                Text("Brighter means trained more recently. Most muscles are ready again after 48–72 hours.")
                    .font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    ForEach(list.reversed(), id: \.muscle) { s in
                        HStack {
                            Circle().fill(color(s)).frame(width: 10, height: 10)
                            Text(s.muscle.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if s.sets > 0 {
                                Text("\(s.sets) sets · 4 days").font(.caption).foregroundStyle(Theme.textTertiary)
                            }
                            Text(s.label).font(.caption.weight(.bold)).foregroundStyle(color(s))
                                .frame(width: 92, alignment: .trailing)
                        }
                        .padding(.vertical, 9)
                        .background(selection == s.muscle ? Theme.accentSoft : Color.clear)
                        Divider().overlay(Theme.border)
                    }
                }
                .primeCard()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .primeBackground()
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func color(_ s: Status) -> Color {
        switch s.label {
        case "Just worked": return Theme.danger
        case "Recovering": return Theme.warning
        case "Nearly ready": return Theme.accentHighlight
        default: return Theme.success
        }
    }
}
