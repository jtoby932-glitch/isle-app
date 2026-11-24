import SwiftUI
import SwiftData

/// Saved days and part-days that drop onto any day in one tap.
struct RoutinesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.order) private var routines: [Routine]
    @Query private var tasks: [TaskItem]
    @State private var path: [Routine] = []

    private var store: Store { Store(context: context) }
    private var todayHasTasks: Bool { tasks.contains { $0.dayKey == Day.today } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save a usual day, a morning or a gym day once. Then it's one tap to drop it onto any day.")
                        .font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted)

                    HStack(spacing: 8) {
                        Button { saveToday() } label: { Label("Save today", systemImage: "square.and.arrow.down") }
                            .buttonStyle(ChunkyButtonStyle(fill: todayHasTasks ? T.primary : T.line, height: 48, shadow: false))
                            .disabled(!todayHasTasks)
                        Button { newRoutine() } label: { Label("New", systemImage: "plus") }
                            .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 48, shadow: false))
                    }

                    if routines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ideas").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                            ForEach(Self.starters.indices, id: \.self) { index in
                                let s = Self.starters[index]
                                Button { addStarter(s) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(s.name).font(.isle(.headline, .heavy)).foregroundStyle(T.ink)
                                            Text(s.items.map(\.title).joined(separator: " · "))
                                                .font(.isle(.caption, .semibold)).foregroundStyle(T.muted).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(T.primary)
                                    }
                                    .card()
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                    }

                    ForEach(routines) { r in routineCard(r) }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.isle(.headline))
                }
            }
            .navigationDestination(for: Routine.self) { r in RoutineEditorView(routine: r) }
        }
    }

    private func routineCard(_ r: Routine) -> some View {
        let items = r.items
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(T.habit(r.colorIndex)).frame(width: 12, height: 12)
                Text(r.name).font(.isle(.headline, .heavy)).foregroundStyle(T.ink)
                Spacer()
                Text("\(items.count) · \(Fmt.duration(r.totalMinutes))").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items.prefix(5)) { i in
                    HStack(spacing: 6) {
                        Text(i.start.map { Fmt.clock($0) } ?? "any")
                            .font(.isle(.caption2, .heavy)).foregroundStyle(T.muted)
                            .frame(width: 40, alignment: .leading)
                        Text(i.title).font(.isle(.caption, .bold)).foregroundStyle(T.ink).lineLimit(1)
                        Spacer()
                        Text(Fmt.duration(i.minutes)).font(.isle(.caption2, .bold)).foregroundStyle(T.muted)
                    }
                }
                if items.count > 5 {
                    Text("+\(items.count - 5) more").font(.isle(.caption2, .heavy)).foregroundStyle(T.muted)
                }
            }
            HStack(spacing: 6) {
                Button("Add to today") { apply(r, to: Day.today) }
                    .buttonStyle(PillButtonStyle(fill: T.primary, textColor: T.primaryInk, height: 36))
                Menu {
                    ForEach(1..<8, id: \.self) { offset in
                        let d = Day.add(Day.today, days: offset)
                        Button(Day.relative(d)) { apply(r, to: d) }
                    }
                } label: {
                    Text("Another day…").font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Capsule().fill(T.surface))
                        .overlay(Capsule().strokeBorder(T.outline, lineWidth: 2))
                }
                Spacer()
                Button { path.append(r) } label: { Image(systemName: "pencil") }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Edit \(r.name)")
            }
        }
        .card()
        .contextMenu {
            Button(role: .destructive) {
                Feedback.play(.undo)
                withAnimation { context.delete(r); store.save() }
            } label: { Label("Delete routine", systemImage: "trash") }
        }
    }

    private func apply(_ r: Routine, to day: Int) {
        Feedback.play(.bloom(r.items.count))
        let made = store.apply(r, to: day)
        app.showToast("Added \(r.name) to \(Day.relative(day).lowercased()).") {
            let s = Store(context: context)
            for t in made { s.delete(t) }
        }
        dismiss()
    }

    private func saveToday() {
        Feedback.play(.lift)
        let r = store.addRoutine(name: "My \(Day.longName(Day.today))", items: store.routineItems(fromDay: Day.today))
        path.append(r)
    }

    private func newRoutine() {
        Feedback.play(.lift)
        let r = store.addRoutine(name: "", items: [RoutineItem(title: "", start: nil, minutes: 30)])
        path.append(r)
    }

    private func addStarter(_ s: (name: String, items: [RoutineItem])) {
        Feedback.play(.bloom(s.items.count))
        store.addRoutine(name: s.name, items: s.items)
    }

    static let starters: [(name: String, items: [RoutineItem])] = [
        ("Morning", [
            RoutineItem(title: "Make bed and water", start: 7 * 60, minutes: 10),
            RoutineItem(title: "Breakfast", start: 7 * 60 + 15, minutes: 20),
            RoutineItem(title: "Plan the day", start: 7 * 60 + 40, minutes: 10)
        ]),
        ("Gym day", [
            RoutineItem(title: "Pack gym bag", start: nil, minutes: 10),
            RoutineItem(title: "Gym", start: 17 * 60 + 30, minutes: 75),
            RoutineItem(title: "Protein and stretch", start: 19 * 60, minutes: 15)
        ]),
        ("Wind down", [
            RoutineItem(title: "Tidy for 10", start: 21 * 60, minutes: 10),
            RoutineItem(title: "Read", start: 21 * 60 + 30, minutes: 20),
            RoutineItem(title: "Phone away", start: 22 * 60, minutes: 5)
        ])
    ]
}

/// Edit a routine's name, colour and blocks.
struct RoutineEditorView: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var items: [RoutineItem] = []
    @State private var loaded = false
    @State private var removed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Routine name", text: $routine.name)
                    .font(.isle(.title2, .heavy))
                    .foregroundStyle(T.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<8, id: \.self) { i in
                            Button {
                                Feedback.play(.chip(i))
                                routine.colorIndex = i
                            } label: {
                                Circle().fill(T.habit(i)).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(T.outline, lineWidth: routine.colorIndex == i ? 3 : 0))
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("Colour \(i + 1)")
                        }
                    }
                }

                ForEach($items) { $item in
                    ItemEditor(item: $item) {
                        Feedback.play(.undo)
                        withAnimation { items.removeAll { $0.id == item.id } }
                    }
                }

                Button {
                    Feedback.play(.chip(items.count % 10))
                    let last = items.last
                    let next = last.flatMap { l in l.start.map { $0 + l.minutes } }
                    withAnimation { items.append(RoutineItem(title: "", start: next, minutes: 30)) }
                } label: { Label("Add a block", systemImage: "plus") }
                    .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 46, shadow: false))

                Button(role: .destructive) {
                    removed = true
                    context.delete(routine)
                    try? context.save()
                    dismiss()
                } label: { Text("Delete routine").font(.isle(.subheadline, .heavy)).foregroundStyle(T.danger) }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(routine.name.isEmpty ? "New routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            items = routine.items
            loaded = true
        }
        .onChange(of: items) { _, new in
            guard !removed else { return }
            routine.items = new.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        .onDisappear {
            guard !removed else { return }
            if routine.name.trimmingCharacters(in: .whitespaces).isEmpty { routine.name = "Routine" }
            routine.items = items.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            try? context.save()
        }
    }
}

/// One block in the routine editor.
private struct ItemEditor: View {
    @Binding var item: RoutineItem
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("What", text: $item.title)
                    .font(.isle(.headline, .heavy))
                Button(action: onDelete) { Image(systemName: "xmark") }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Remove block")
            }
            HStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { item.start != nil },
                    set: { item.start = $0 ? (item.start ?? 9 * 60) : nil }
                )) {
                    Text("At a time").font(.isle(.subheadline, .bold))
                }
                .toggleStyle(.switch)
                .tint(T.good)
                .fixedSize()
                if let start = item.start {
                    DatePicker("", selection: Binding(
                        get: { Day.dateAt(Day.today, minutes: start) },
                        set: { d in
                            let c = Day.calendar.dateComponents([.hour, .minute], from: d)
                            item.start = (c.hour ?? 9) * 60 + (c.minute ?? 0)
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
                Spacer()
            }
            HStack {
                Text("Length").font(.isle(.subheadline, .bold)).foregroundStyle(T.muted)
                Spacer()
                Button { item.minutes = max(5, item.minutes - 5) } label: { Image(systemName: "minus") }
                    .buttonStyle(IconButtonStyle())
                Text(Fmt.duration(item.minutes)).font(.isle(.headline, .heavy)).monospacedDigit().frame(minWidth: 64)
                Button { item.minutes = min(8 * 60, item.minutes + 5) } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButtonStyle())
            }
        }
        .foregroundStyle(T.ink)
        .card()
    }
}
