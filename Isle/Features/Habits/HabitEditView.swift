import SwiftUI
import SwiftData

/// Create (habit == nil) or edit a habit.
struct HabitEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var habit: Habit?
    @Query(sort: \Habit.order) private var habits: [Habit]

    @State private var name = ""
    @State private var colorIndex = 0
    @State private var target = 3
    @State private var mask = 127
    @State private var hasTime = false
    @State private var time = Day.dateAt(Day.today, minutes: 8 * 60)
    @State private var minutes = 15
    @State private var lowVersion = ""
    @State private var chainAfter: UUID? = nil
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button("Cancel") { dismiss() }.buttonStyle(PillButtonStyle(height: 40))
                    Spacer()
                    Text(habit == nil ? "New habit" : "Edit habit").font(.isle(.headline)).foregroundStyle(T.ink)
                    Spacer()
                    Button(habit == nil ? "Plant" : "Save") { save() }
                        .buttonStyle(PillButtonStyle(fill: T.primary, textColor: T.primaryInk, height: 40))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                field("Name", text: $name, prompt: "Read 10 pages")

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Colour")
                    HStack(spacing: 8) {
                        ForEach(0..<T.habitColors.count, id: \.self) { i in
                            Button {
                                Feedback.play(.chip(i))
                                colorIndex = i
                            } label: {
                                Circle().fill(T.habit(i))
                                    .overlay(Circle().strokeBorder(T.outline, lineWidth: colorIndex == i ? 3 : 1.5))
                                    .frame(width: 32, height: 32)
                                    .scaleEffect(colorIndex == i ? 1.12 : 1)
                                    .frame(width: 38, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour \(i + 1)")
                            .accessibilityAddTraits(colorIndex == i ? .isSelected : [])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Which days can it happen?")
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { d in
                            let on = (mask >> d) & 1 == 1
                            Button {
                                Feedback.play(.place(d))
                                mask ^= (1 << d)
                                if mask == 0 { mask = 1 << d }
                                target = min(target, dayCount)
                            } label: {
                                Text(Day.letters[d]).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(on ? T.primarySoft : T.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.outline, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Day.longNames[d])
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Target")
                    HStack {
                        Text(target >= 7 ? "Every day" : "\(target)× a week").font(.isle(.title3, .heavy)).foregroundStyle(T.ink)
                        Spacer()
                        Stepper("", value: $target, in: 1...max(1, dayCount))
                            .labelsHidden()
                            .onChange(of: target) { _, _ in Feedback.play(.chip(target)) }
                    }
                    .padding(.horizontal, 12).frame(minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 4) {
                    ToggleSwitch(label: "A usual time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .font(.isle(.subheadline))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "How long?")
                    FlowLayout(spacing: 6) {
                        ForEach([1, 5, 10, 15, 20, 30, 45, 60], id: \.self) { m in
                            ToggleChip(text: Fmt.duration(m), on: minutes == m) {
                                Feedback.play(.chip(m / 10))
                                minutes = m
                            }
                        }
                    }
                }

                field("Low-battery version (optional)", text: $lowVersion, prompt: "e.g. 20 min walk instead")
                Text("Shown on low-energy days instead, for double shells. Still counts.")
                    .font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -8)

                let others = habits.filter { $0.id != habit?.id }
                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Chain after (optional)")
                        FlowLayout(spacing: 6) {
                            ToggleChip(text: "None", on: chainAfter == nil) { Feedback.play(.tap); chainAfter = nil }
                            ForEach(others) { o in
                                ToggleChip(text: o.name, on: chainAfter == o.id) { Feedback.play(.tap); chainAfter = o.id }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .onAppear(perform: load)
        .animation(.easeOut(duration: 0.2), value: hasTime)
    }

    private var dayCount: Int { (0..<7).filter { (mask >> $0) & 1 == 1 }.count }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: label)
            TextField(prompt, text: text)
                .font(.isle(.headline))
                .padding(.horizontal, 12).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let h = habit {
            name = h.name
            colorIndex = h.colorIndex
            target = h.targetPerWeek
            mask = h.daysMask
            hasTime = h.timeMinutes != nil
            time = Day.dateAt(Day.today, minutes: h.timeMinutes ?? 8 * 60)
            minutes = h.minutes
            lowVersion = h.lowBatteryVersion
            chainAfter = h.chainAfterID
        } else {
            colorIndex = habits.count % T.habitColors.count
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var timeMinutes: Int? = nil
        if hasTime {
            let c = Day.calendar.dateComponents([.hour, .minute], from: time)
            timeMinutes = (c.hour ?? 8) * 60 + (c.minute ?? 0)
        }
        let h: Habit
        if let existing = habit {
            h = existing
        } else {
            h = Store(context: context).addHabit(name: trimmed, colorIndex: colorIndex, target: target)
        }
        h.name = trimmed
        h.colorIndex = colorIndex
        h.targetPerWeek = min(target, dayCount)
        h.daysMask = mask
        h.timeMinutes = timeMinutes
        h.minutes = minutes
        h.lowBatteryVersion = lowVersion.trimmingCharacters(in: .whitespaces)
        h.chainAfterID = chainAfter
        try? context.save()
        Feedback.play(habit == nil ? .bloom(colorIndex) : .tick)
        dismiss()
    }
}
