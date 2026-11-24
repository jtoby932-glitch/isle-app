import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Query private var journal: [JournalEntry]

    @State private var query = ""
    @State private var filter = 0
    @FocusState private var focused: Bool

    struct Result: Identifiable {
        let id: String
        let title: String
        let sub: String
        let kind: String
        let color: Color
        let done: Bool
        let task: TaskItem?
        let habit: Habit?
    }

    private var results: [Result] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var out: [Result] = []
        if filter == 0 || filter == 1 || filter == 3 {
            for t in tasks {
                if filter == 3 && !t.isDone { continue }
                if filter == 1 && t.isDone { continue }
                if !q.isEmpty && !t.title.lowercased().contains(q) { continue }
                var sub = t.dayKey.map { Day.relative($0) } ?? "Inbox"
                if let s = t.startMinutes { sub += " \(Fmt.clock(s))" }
                sub += " · \(Fmt.duration(t.minutes))"
                if t.isDone { sub += " · done" }
                out.append(Result(id: "t\(t.id)", title: t.title, sub: sub, kind: "Task", color: t.priority ? T.primary : T.habit(4), done: t.isDone, task: t, habit: nil))
            }
        }
        if filter == 0 || filter == 2 {
            for h in habits where q.isEmpty || h.name.lowercased().contains(q) {
                let sub = (h.isDaily ? "Every day" : "\(h.targetPerWeek)× a week") + (h.timeMinutes.map { " · \(Fmt.clock($0))" } ?? "")
                out.append(Result(id: "h\(h.id)", title: h.name, sub: sub, kind: "Habit", color: T.habit(h.colorIndex), done: false, task: nil, habit: h))
            }
        }
        if filter == 0 && !q.isEmpty {
            for j in journal where j.text.lowercased().contains(q) {
                out.append(Result(id: "j\(j.dayKey)", title: j.text, sub: "Journal · \(Day.title(j.dayKey))", kind: "Journal", color: T.lilacStrong, done: false, task: nil, habit: nil))
            }
        }
        return Array(out.sorted { a, b in a.done == b.done ? a.title < b.title : !a.done }.prefix(60))
    }

    var body: some View {
        let list = results
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .bold)).foregroundStyle(T.ink)
                    TextField("Search everything", text: $query)
                        .font(.isle(.headline))
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2.5))
                Button("Done") { dismiss() }.font(.isle(.headline)).foregroundStyle(T.ink).frame(minHeight: 44)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(["All", "Tasks", "Habits", "Done"].enumerated()), id: \.offset) { i, label in
                        ToggleChip(text: label, on: filter == i) { Feedback.play(.tap); filter = i }
                    }
                }
            }
            Text(query.isEmpty ? "Everything" : "\(list.count) result\(list.count == 1 ? "" : "s") for “\(query)”")
                .font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(list) { r in
                        Button {
                            Feedback.play(.tap)
                            if let t = r.task { dismiss(); app.editingTask = t }
                            if let h = r.habit { dismiss(); app.openHabit = h }
                        } label: {
                            HStack(spacing: 10) {
                                Rectangle().fill(r.color).frame(width: 6)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(r.title).font(.isle(.body, .heavy)).foregroundStyle(r.done ? T.muted : T.ink)
                                        .strikethrough(r.done).lineLimit(2)
                                    Text(r.sub).font(.isle(.caption, .bold)).foregroundStyle(T.muted)
                                }
                                Spacer()
                                IsleTag(text: r.kind).padding(.trailing, 10)
                            }
                            .frame(minHeight: 54)
                            .background(T.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                        }
                        .buttonStyle(PressStyle())
                    }
                    if list.isEmpty && !query.isEmpty {
                        VStack(spacing: 8) {
                            PipView(mood: .normal, size: 100)
                            Text("Nothing called “\(query)” yet").font(.isle(.headline)).foregroundStyle(T.ink)
                            Button("Quick-add it") {
                                dismiss()
                                app.showQuickAdd = true
                            }
                            .buttonStyle(ChunkyButtonStyle(height: 46))
                            .frame(width: 200)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(16)
        .screenBackground()
        .onAppear { focused = true }
    }
}
