import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem

    @State private var draftStep = ""
    @State private var steps: [TaskStep] = []
    @State private var hasTime = false
    @State private var time = Date()
    @State private var loaded = false

    private let durations = [15, 30, 45, 60, 90, 120, 180, 240]
    private let reminders: [(Int?, String)] = [(nil, "Off"), (0, "At start"), (10, "10 min before"), (30, "30 min before")]

    private var dayOptions: [Int?] {
        let today = Day.today
        return (0..<14).map { Optional(Day.add(today, days: $0)) } + [nil]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button("Cancel") { dismiss() }.buttonStyle(PillButtonStyle(height: 40))
                    Spacer()
                    Text("Edit task").font(.isle(.headline)).foregroundStyle(T.ink)
                    Spacer()
                    Button("Save") { commit(); Feedback.play(.tick); dismiss() }
                        .buttonStyle(PillButtonStyle(fill: T.primary, textColor: T.primaryInk, height: 40))
                }

                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Task")
                    TextField("What needs doing?", text: $task.title)
                        .font(.isle(.title3, .heavy))
                        .padding(.horizontal, 12).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Day")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(dayOptions.enumerated()), id: \.offset) { _, d in
                                ToggleChip(text: d.map { Day.relative($0) } ?? "Someday", on: task.dayKey == d) {
                                    if let d { Feedback.play(.place(Day.weekday(d))) } else { Feedback.play(.tap) }
                                    task.dayKey = d
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ToggleSwitch(label: "Set a start time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Start", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .font(.isle(.subheadline))
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "How long?")
                    IsleFlowLayout(spacing: 6) {
                        ForEach(durations, id: \.self) { m in
                            ToggleChip(text: Fmt.duration(m), on: task.minutes == m) {
                                Feedback.play(.chip(durations.firstIndex(of: m) ?? 0))
                                task.minutes = m
                                task.size = TaskItem.size(for: m)
                            }
                        }
                    }
                }

                ToggleSwitch(label: "One of this week's top 3", isOn: $task.priority)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Steps · \(steps.filter { $0.done }.count) of \(steps.count)")
                    VStack(spacing: 0) {
                        ForEach($steps) { $step in
                            HStack(spacing: 8) {
                                Button {
                                    step.done.toggle()
                                    Feedback.play(step.done ? .tick : .undo)
                                } label: {
                                    CheckCircle(done: step.done, size: 22).frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(step.done ? "Undo \(step.title)" : "Complete \(step.title)")
                                Text(step.title).font(.isle(.subheadline, .heavy))
                                    .foregroundStyle(step.done ? T.muted : T.ink)
                                    .strikethrough(step.done)
                                Spacer()
                                Button {
                                    Feedback.play(.undo)
                                    withAnimation { steps.removeAll { $0.id == step.id } }
                                } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .black)).foregroundStyle(T.muted) }
                                .buttonStyle(.plain)
                                .frame(width: 36, height: 44)
                                .accessibilityLabel("Remove step")
                            }
                            Divider().overlay(T.line)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .black)).foregroundStyle(T.muted).frame(width: 44)
                            TextField("Add a step", text: $draftStep)
                                .font(.isle(.subheadline, .heavy))
                                .submitLabel(.done)
                                .onSubmit(addStep)
                            Button("Add", action: addStep).buttonStyle(PillButtonStyle(height: 32))
                                .padding(.trailing, 8)
                        }
                        .frame(minHeight: 48)
                    }
                    .background(RoundedRectangle(cornerRadius: 14).fill(T.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Remind me")
                    HStack(spacing: 6) {
                        ForEach(Array(reminders.enumerated()), id: \.offset) { _, r in
                            ToggleChip(text: r.1, on: task.remindBefore == r.0) {
                                Feedback.play(.tap)
                                task.remindBefore = r.0
                            }
                        }
                    }
                    if task.remindBefore != nil && !hasTime {
                        Text("Reminders need a start time.").font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
                    }
                }

                if task.isDone {
                    Button("Mark as not done") {
                        Store(context: context).toggle(task)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 46, shadow: false))
                }

                Button {
                    let snapshot = Snapshot(task)
                    Feedback.play(.whoosh)
                    Store(context: context).delete(task)
                    app.showToast("Task deleted") {
                        let restored = snapshot.restore()
                        context.insert(restored)
                        try? context.save()
                    }
                    dismiss()
                } label: {
                    Text("Delete task").font(.isle(.subheadline)).foregroundStyle(T.danger)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.danger, lineWidth: 2))
                }
                .buttonStyle(PressStyle())
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .onAppear(perform: load)
        .onDisappear(perform: commit)
        .animation(.easeOut(duration: 0.2), value: hasTime)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        steps = task.steps
        hasTime = task.startMinutes != nil
        time = Day.dateAt(task.dayKey ?? Day.today, minutes: task.startMinutes ?? 9 * 60)
    }

    private func commit() {
        guard loaded, !task.isDeleted else { return }
        task.steps = steps
        if hasTime {
            let c = Day.calendar.dateComponents([.hour, .minute], from: time)
            task.startMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
        } else {
            task.startMinutes = nil
        }
        if task.title.trimmingCharacters(in: .whitespaces).isEmpty { task.title = "Untitled task" }
        try? context.save()
    }

    private func addStep() {
        let t = draftStep.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { steps.append(TaskStep(title: t)) }
        Feedback.play(.chip(steps.count + 1))
        draftStep = ""
    }

    /// Enough of a task to bring it back after a delete.
    struct Snapshot {
        let title: String, dayKey: Int?, start: Int?, minutes: Int, priority: Bool, steps: Data, remind: Int?
        init(_ t: TaskItem) {
            title = t.title; dayKey = t.dayKey; start = t.startMinutes; minutes = t.minutes
            priority = t.priority; steps = t.stepsData; remind = t.remindBefore
        }
        func restore() -> TaskItem {
            let t = TaskItem(title: title, dayKey: dayKey, startMinutes: start, minutes: minutes)
            t.priority = priority; t.stepsData = steps; t.remindBefore = remind
            return t
        }
    }
}
